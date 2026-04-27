<script lang="ts">
	import { imageUrl } from '$lib/api';
	import { appState } from '$lib/stores.svelte';
</script>

{#if appState.drag?.active}
	<div
		class="pointer-events-none fixed z-[9999]"
		style="
			left: {appState.drag.x}px;
			top: {appState.drag.y}px;
			transform: translate(-50%, -50%) rotate(-4deg) scale(1.08);
		"
	>
		<div
			class="overflow-hidden rounded-sm bg-white p-1.5"
			style="box-shadow: 0 8px 32px rgba(0,0,0,0.45);"
		>
			<img
				src={imageUrl(appState.drag.image.path)}
				alt=""
				class="h-24 w-32 object-cover"
				draggable="false"
			/>
		</div>
	</div>
{/if}
