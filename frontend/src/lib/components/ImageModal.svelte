<script lang="ts">
	import { imageUrl, type ImageData } from '$lib/api';

	let {
		image,
		gallery = [],
		onclose
	}: { image: ImageData; gallery?: ImageData[]; onclose: () => void } = $props();

	let currentIndex = $state(0);

	// Sync index when image/gallery changes
	$effect(() => {
		if (gallery.length > 1) {
			const idx = gallery.findIndex((g) => g.id === image.id);
			currentIndex = idx >= 0 ? idx : 0;
		} else {
			currentIndex = 0;
		}
	});

	let current = $derived(gallery.length > 1 ? gallery[currentIndex] : image);
	let hasNext = $derived(gallery.length > 1 && currentIndex < gallery.length - 1);
	let hasPrev = $derived(gallery.length > 1 && currentIndex > 0);

	function next() {
		if (hasNext) currentIndex++;
	}
	function prev() {
		if (hasPrev) currentIndex--;
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') onclose();
		if (e.key === 'ArrowRight') next();
		if (e.key === 'ArrowLeft') prev();
	}

	// Swipe support
	let pointerStartX = 0;
	let swiping = false;

	function onPointerDown(e: PointerEvent) {
		pointerStartX = e.clientX;
		swiping = true;
	}

	function onPointerUp(e: PointerEvent) {
		if (!swiping) return;
		swiping = false;
		const dx = e.clientX - pointerStartX;
		if (Math.abs(dx) > 50) {
			if (dx < 0) next();
			else prev();
		}
	}
</script>

<svelte:window onkeydown={handleKeydown} />

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
	class="fixed inset-0 z-50 flex items-center justify-center bg-black/80"
	onclick={onclose}
	onkeydown={handleKeydown}
>
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div
		class="relative max-h-[90vh] max-w-[90vw]"
		onclick={(e) => e.stopPropagation()}
		onpointerdown={onPointerDown}
		onpointerup={onPointerUp}
		style="touch-action: pan-y;"
	>
		<img
			src={imageUrl(current.path)}
			alt={current.author}
			class="max-h-[90vh] max-w-[90vw] rounded-xl object-contain shadow-2xl"
			draggable="false"
		/>

		<!-- Close -->
		<button
			onclick={onclose}
			class="absolute top-3 right-3 flex h-10 w-10 items-center justify-center rounded-full bg-white/90 text-xl text-dark shadow"
		>
			✕
		</button>

		<!-- Info -->
		<div
			class="absolute bottom-3 left-3 rounded-lg bg-white/90 px-3 py-1 text-sm text-dark shadow"
		>
			{current.author}{#if current.date}&nbsp;· {current.date}{/if}
			{#if gallery.length > 1}
				<span class="ml-2 text-dark/40">{currentIndex + 1}/{gallery.length}</span>
			{/if}
		</div>

		<!-- Prev / Next arrows -->
		{#if hasPrev}
			<button
				onclick={prev}
				class="absolute top-1/2 left-3 flex h-10 w-10 -translate-y-1/2 items-center justify-center rounded-full bg-white/90 text-xl text-dark shadow"
			>
				&#8249;
			</button>
		{/if}
		{#if hasNext}
			<button
				onclick={next}
				class="absolute top-1/2 right-3 flex h-10 w-10 -translate-y-1/2 items-center justify-center rounded-full bg-white/90 text-xl text-dark shadow"
			>
				&#8250;
			</button>
		{/if}
	</div>
</div>
