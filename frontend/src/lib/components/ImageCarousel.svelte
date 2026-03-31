<script lang="ts">
	import { imageUrl, type ImageData } from '$lib/api';
	import { appState, beginDrag } from '$lib/stores.svelte';

	let { images }: { images: ImageData[] } = $props();

	function seededRotation(id: number): number {
		const hash = ((id * 2654435761) >>> 0) % 360;
		return (hash % 21) - 10;
	}

	function seededOffset(id: number): { x: number; y: number } {
		const h1 = ((id * 1664525 + 1013904223) >>> 0) % 100;
		const h2 = ((id * 22695477 + 1) >>> 0) % 100;
		return { x: (h1 % 20) - 10, y: (h2 % 10) - 5 };
	}
</script>

<div class="relative w-full overflow-hidden bg-white px-6 py-6" style="min-height: 180px;">
	<div class="flex items-center justify-start gap-0" style="min-height: 150px;">
		{#each images as img, i (img.id)}
			{@const rot = seededRotation(img.id)}
			{@const off = seededOffset(img.id)}
			{@const isDragging = appState.drag?.active && appState.drag?.image.id === img.id}
			<!-- svelte-ignore a11y_no_static_element_interactions -->
			<div
				class="photo-card relative -ml-12 first:ml-0 flex-shrink-0 cursor-grab transition-all hover:scale-110"
				class:opacity-30={isDragging}
				class:scale-95={isDragging}
				style="
					transform: rotate({rot}deg) translate({off.x}px, {off.y}px);
					z-index: {isDragging ? 0 : images.length - i};
					touch-action: none;
				"
				onpointerdown={(e) => beginDrag(e, img, 'carousel')}
				role="img"
				aria-label={img.author}
			>
				<div
					class="overflow-hidden rounded-sm bg-white p-1.5 shadow-lg"
					style="box-shadow: 0 2px 12px rgba(0,0,0,0.35);"
				>
					<img
						src={imageUrl(img.path)}
						alt={img.author}
						class="h-32 w-44 object-cover"
						draggable="false"
					/>
				</div>
			</div>
		{/each}

		{#if images.length === 0}
			<p class="w-full py-4 text-center text-sm text-white/40">
				Aucune image — uploadez depuis votre téléphone !
			</p>
		{/if}
	</div>
</div>
