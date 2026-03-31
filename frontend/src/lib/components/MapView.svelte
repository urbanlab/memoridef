<script lang="ts">
	import { imageUrl, updateImage, type ImageData } from '$lib/api';
	import { appState, beginDrag, wasDragging } from '$lib/stores.svelte';
	import ImageModal from './ImageModal.svelte';

	let { images }: { images: ImageData[] } = $props();

	let mapContainer = $state<HTMLDivElement>(undefined!);
	let modalImage = $state<ImageData | null>(null);
	let modalGallery = $state<ImageData[]>([]);
	let expandedClusterId = $state<string | null>(null);

	const CLUSTER_RADIUS = 0.05;

	interface Cluster {
		id: string;
		x: number;
		y: number;
		images: ImageData[];
	}

	let clusters = $derived.by(() => {
		const result: Cluster[] = [];
		const used = new Set<number>();
		const dragId =
			appState.drag?.active && appState.drag.source === 'map'
				? appState.drag.image.id
				: null;

		for (const img of images) {
			if (
				used.has(img.id) ||
				img.id === dragId ||
				img.location_x == null ||
				img.location_y == null
			)
				continue;

			const cluster: Cluster = {
				id: `${img.location_x.toFixed(3)}_${img.location_y.toFixed(3)}`,
				x: img.location_x,
				y: img.location_y,
				images: [img]
			};
			used.add(img.id);

			for (const other of images) {
				if (
					used.has(other.id) ||
					other.id === dragId ||
					other.location_x == null ||
					other.location_y == null
				)
					continue;
				const dx = img.location_x - other.location_x;
				const dy = img.location_y - other.location_y;
				if (Math.sqrt(dx * dx + dy * dy) < CLUSTER_RADIUS) {
					cluster.images.push(other);
					used.add(other.id);
				}
			}

			cluster.images.sort(
				(a, b) => new Date(a.upload_date).getTime() - new Date(b.upload_date).getTime()
			);
			result.push(cluster);
		}
		return result;
	});

	// Close expanded cluster if it no longer exists
	$effect(() => {
		if (expandedClusterId && !clusters.find((c) => c.id === expandedClusterId)) {
			expandedClusterId = null;
		}
	});

	function handleClusterClick(cluster: Cluster) {
		if (wasDragging()) return;
		if (cluster.images.length > 1) {
			expandedClusterId = expandedClusterId === cluster.id ? null : cluster.id;
		} else {
			modalGallery = [];
			modalImage = cluster.images[0];
		}
	}

	function handleImageClick(img: ImageData, cluster: Cluster) {
		if (wasDragging()) return;
		modalGallery = cluster.images;
		modalImage = img;
	}

	// Close expanded on drag start
	$effect(() => {
		if (appState.drag?.active) {
			expandedClusterId = null;
		}
	});

	/** Masonry-like grid positions for N items around a center point */
	function masonryOffsets(count: number): { col: number; row: number }[] {
		// Lay out in a grid, roughly square
		const cols = Math.ceil(Math.sqrt(count));
		return Array.from({ length: count }, (_, i) => ({
			col: i % cols,
			row: Math.floor(i / cols)
		}));
	}

	export function pageToMapCoords(
		clientX: number,
		clientY: number
	): { x: number; y: number } | null {
		if (!mapContainer) return null;
		const rect = mapContainer.getBoundingClientRect();
		const x = (clientX - rect.left) / rect.width;
		const y = (clientY - rect.top) / rect.height;
		if (x < 0 || x > 1 || y < 0 || y > 1) return null;
		return { x, y };
	}

	export function handleDrop(
		clientX: number,
		clientY: number,
		drag: { image: ImageData; source: string; active: boolean }
	) {
		if (!drag.active) return;

		const coords = pageToMapCoords(clientX, clientY);
		if (!coords) return;

		const img = drag.image;

		if (drag.source === 'carousel') {
			updateImage(img.id, {
				location_x: coords.x,
				location_y: coords.y,
				date: appState.selectedDate
			}).then((updated) => {
				appState.carouselImages = appState.carouselImages.filter((i) => i.id !== img.id);
				appState.placedImages = [...appState.placedImages, updated];
			});
		} else {
			updateImage(img.id, {
				location_x: coords.x,
				location_y: coords.y
			}).then((updated) => {
				appState.placedImages = appState.placedImages.map((i) =>
					i.id === updated.id ? updated : i
				);
			});
		}
	}
</script>

<div
	bind:this={mapContainer}
	class="relative h-full w-full overflow-hidden rounded-lg border border-accent/30"
	onclick={() => {
		if (!wasDragging()) expandedClusterId = null;
	}}
	role="application"
	aria-label="Carte"
>
	<!-- Map background -->
	<img src="/map2.png" alt="Carte" class="h-full w-full object-contain" draggable="false" />

	<!-- Drop zone highlight when actively dragging -->
	{#if appState.drag?.active}
		<div
			class="pointer-events-none absolute inset-0 z-30 rounded-lg border-4 border-dashed border-accent/30 bg-accent/5"
		></div>
	{/if}

	<!-- Image clusters -->
	{#each clusters as cluster}
		{@const isExpanded = expandedClusterId === cluster.id}
		{@const offsets = masonryOffsets(cluster.images.length)}
		{@const cols = Math.ceil(Math.sqrt(cluster.images.length))}
		{@const cardW = 96}
		{@const cardH = 80}
		{@const gap = 6}

		<div
			class="absolute -translate-x-1/2 -translate-y-1/2"
			style="left: {cluster.x * 100}%; top: {cluster.y * 100}%; z-index: {isExpanded ? 35 : 10};"
			onclick={(e) => e.stopPropagation()}
		>
			{#if isExpanded}
				<!-- Expanded masonry: images laid out in a grid directly on map -->
				{@const gridW = cols * (cardW + gap) - gap}
				{@const rows = Math.ceil(cluster.images.length / cols)}
				{@const gridH = rows * (cardH + gap) - gap}
				<div
					class="relative"
					style="width: {gridW}px; height: {gridH}px; margin-left: {-gridW / 2}px; margin-top: {-gridH / 2}px;"
				>
					{#each cluster.images as img, i (img.id)}
						{@const col = offsets[i].col}
						{@const row = offsets[i].row}
						<!-- svelte-ignore a11y_no_static_element_interactions -->
						<div
							class="absolute cursor-grab rounded-sm bg-white p-1 shadow-lg active:cursor-grabbing transition-all duration-200"
							style="
								left: {col * (cardW + gap)}px;
								top: {row * (cardH + gap)}px;
								width: {cardW}px;
								height: {cardH}px;
								box-shadow: 0 3px 12px rgba(0,0,0,0.3);
								touch-action: none;
							"
							onpointerdown={(e) => beginDrag(e, img, 'map')}
							onclick={() => handleImageClick(img, cluster)}
							role="button"
							tabindex="0"
							onkeydown={() => {}}
						>
							<img
								src={imageUrl(img.path)}
								alt={img.author}
								class="h-full w-full rounded-[1px] object-cover"
								draggable="false"
							/>
						</div>
					{/each}
				</div>
			{:else}
				<!-- Collapsed: stacked photos with rotation -->
				<div class="relative h-20 w-24 transition-transform hover:scale-110">
					{#each cluster.images as img, i}
						{@const rotation = (i - Math.floor(cluster.images.length / 2)) * 6}
						<!-- svelte-ignore a11y_no_static_element_interactions -->
						<div
							class="absolute inset-0 cursor-grab rounded-sm bg-white p-1 shadow-lg active:cursor-grabbing"
							style="
								transform: rotate({rotation}deg);
								z-index: {i};
								box-shadow: 0 2px 10px rgba(0,0,0,0.3);
								touch-action: none;
							"
							onpointerdown={(e) => {
								if (cluster.images.length === 1) beginDrag(e, img, 'map');
							}}
							onclick={() => handleClusterClick(cluster)}
							role="button"
							tabindex="0"
							onkeydown={() => {}}
						>
							<img
								src={imageUrl(img.path)}
								alt={img.author}
								class="h-full w-full object-cover"
								draggable="false"
							/>
						</div>
					{/each}
					{#if cluster.images.length > 1}
						<span
							class="absolute -top-2 -right-2 z-50 flex h-5 w-5 items-center justify-center rounded-full bg-accent text-[10px] font-bold text-white shadow"
						>
							{cluster.images.length}
						</span>
					{/if}
				</div>
			{/if}
		</div>
	{/each}
</div>

{#if modalImage}
	<ImageModal image={modalImage} gallery={modalGallery} onclose={() => { modalImage = null; modalGallery = []; }} />
{/if}
