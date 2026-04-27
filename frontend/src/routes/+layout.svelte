<script lang="ts">
	import './layout.css';

	let { children } = $props();
</script>

<svelte:head>
	<title>Memor'IDEF</title>
</svelte:head>

{@render children()}
