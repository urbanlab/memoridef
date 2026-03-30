<script lang="ts">
	import { onMount } from 'svelte';
	import { fetchImages, fetchUnplacedImages, fetchDatesWithImages } from '$lib/api';
	import { appState, moveDrag, endDrag, markDragEnd } from '$lib/stores.svelte';
	import MapView from '$lib/components/MapView.svelte';
	import ImageCarousel from '$lib/components/ImageCarousel.svelte';
	import TimelineScroller from '$lib/components/TimelineScroller.svelte';
	import DragGhost from '$lib/components/DragGhost.svelte';

	let pollInterval: ReturnType<typeof setInterval>;
	let mapView: MapView;

	async function loadData() {
		const [unplaced, dates] = await Promise.all([
			fetchUnplacedImages(),
			fetchDatesWithImages()
		]);
		appState.carouselImages = unplaced;
		appState.availableDates = dates;
	}

	let filteredPlacedImages = $derived.by(() => {
		return appState.placedImages.filter((img) => {
			if (!img.date) return false;
			return img.date <= appState.selectedDate;
		});
	});

	async function loadPlacedImages() {
		const placed = await fetchImages();
		appState.placedImages = placed.filter((img) => img.location_x != null);
	}

	onMount(() => {
		loadData();
		loadPlacedImages();

		pollInterval = setInterval(() => {
			loadData();
			loadPlacedImages();
		}, 3000);

		// Global pointer handlers on document (bypasses pointer capture issues)
		function onPointerMove(e: PointerEvent) {
			if (!appState.drag) return;
			e.preventDefault();
			moveDrag(e);
		}

		function onPointerUp(e: PointerEvent) {
			const drag = endDrag();
			if (!drag) return;
			if (drag.active) {
				markDragEnd();
				mapView?.handleDrop(e.clientX, e.clientY, drag);
			}
		}

		function onKeydown(e: KeyboardEvent) {
			if (e.key === 'Escape' && appState.drag) {
				endDrag();
			}
		}

		// Use capture phase so we get events before any element captures the pointer
		document.addEventListener('pointermove', onPointerMove, { capture: true });
		document.addEventListener('pointerup', onPointerUp, { capture: true });
		document.addEventListener('keydown', onKeydown);

		return () => {
			clearInterval(pollInterval);
			document.removeEventListener('pointermove', onPointerMove, { capture: true });
			document.removeEventListener('pointerup', onPointerUp, { capture: true });
			document.removeEventListener('keydown', onKeydown);
		};
	});
</script>

<div
	class="flex h-dvh w-dvw flex-col overflow-hidden bg-dark"
	class:select-none={appState.drag?.active}
	class:cursor-grabbing={appState.drag?.active}
>
	<!-- Main area: map + timeline -->
	<div class="flex min-h-0 flex-1">
		<!-- Map -->
		<div class="min-w-0 flex-1 bg-accent-light">
			<MapView bind:this={mapView} images={filteredPlacedImages} />
		</div>

		<!-- Timeline scroller (right) -->
		<TimelineScroller availableDates={appState.availableDates} />
	</div>

	<!-- Image carousel (bottom) -->
	<ImageCarousel images={appState.carouselImages} />
</div>

<!-- Floating drag ghost follows pointer -->
<DragGhost />
