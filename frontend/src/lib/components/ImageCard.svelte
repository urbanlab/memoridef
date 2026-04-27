<script lang="ts">
	import { imageUrl, type ImageData } from '$lib/api';

	let { image, style = '', onclick = undefined }: { image: ImageData; style?: string; onclick?: () => void } =
		$props();
</script>

<button
	class="image-card cursor-pointer overflow-hidden rounded-lg bg-white shadow-md transition-shadow hover:shadow-lg"
	{style}
	{onclick}
	type="button"
>
	<img src={imageUrl(image.path)} alt={image.author} class="h-full w-full object-cover" draggable="false" />
</button>

<style>
	.image-card {
		border: 3px solid white;
	}
</style>
