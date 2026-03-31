<script lang="ts">
	import {
		uploadFiles,
		deleteImage,
		imageUrl,
		renameSession,
		randomizeSessionName,
		fetchRandomName,
		type ImageData
	} from '$lib/api';
	import { onMount } from 'svelte';

	let sessionId = $state<string | undefined>(undefined);
	let author = $state('');
	let editingName = $state(false);
	let nameInput = $state('');
	let uploadedImages = $state<ImageData[]>([]);
	let uploading = $state(false);
	let fileInput = $state<HTMLInputElement>(undefined!);
	let nameInputEl = $state<HTMLInputElement>(undefined!);

	onMount(async () => {
		// Pre-generate a name before first upload
		author = await fetchRandomName();
	});

	async function handleFiles(e: Event) {
		const input = e.target as HTMLInputElement;
		if (!input.files?.length) return;

		uploading = true;
		try {
			const res = await uploadFiles(input.files, sessionId);
			sessionId = res.session_id;
			// If this is the first upload and user had a pre-generated name, rename the session
			if (author && author !== res.author && uploadedImages.length === 0) {
				const renamed = await renameSession(res.session_id, author);
				author = renamed.author;
			} else {
				author = res.author;
			}
			uploadedImages = [...uploadedImages, ...res.images];
		} finally {
			uploading = false;
			input.value = '';
		}
	}

	async function removeImage(img: ImageData) {
		await deleteImage(img.id);
		uploadedImages = uploadedImages.filter((i) => i.id !== img.id);
	}

	function openPicker() {
		fileInput.click();
	}

	function startEditName() {
		nameInput = author;
		editingName = true;
		// Focus input on next tick
		setTimeout(() => nameInputEl?.focus(), 0);
	}

	async function saveName() {
		editingName = false;
		const trimmed = nameInput.trim();
		if (!trimmed || trimmed === author) return;
		author = trimmed;
		if (sessionId) {
			const res = await renameSession(sessionId, trimmed);
			author = res.author;
		}
	}

	function handleNameKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter') saveName();
		if (e.key === 'Escape') {
			editingName = false;
		}
	}

	async function refreshName() {
		if (sessionId) {
			const res = await randomizeSessionName(sessionId);
			author = res.author;
		} else {
			author = await fetchRandomName();
		}
	}
</script>

<div class="flex h-dvh flex-col items-center overflow-y-auto bg-accent-light px-4 pt-8 pb-8">
	<!-- Title -->
	<h1 class="mb-6 text-3xl font-black tracking-tight text-accent">MEMOR'IDEF</h1>

	<!-- Author name section -->
	<div class="mb-6 flex w-full max-w-sm flex-col items-center gap-2">
		<span class="text-xs text-dark/40">Vous postez en tant que</span>
		<div class="flex items-center gap-2">
			{#if editingName}
				<input
					bind:this={nameInputEl}
					bind:value={nameInput}
					onblur={saveName}
					onkeydown={handleNameKeydown}
					class="rounded-lg border-2 border-accent/30 bg-white px-3 py-1.5 text-center text-sm font-bold text-accent outline-none focus:border-accent"
				/>
			{:else}
				<button
					onclick={startEditName}
					class="rounded-lg border-2 border-transparent px-3 py-1.5 text-sm font-bold text-accent transition hover:border-accent/20 hover:bg-white/60"
					title="Cliquer pour modifier le nom"
				>
					{author}
				</button>
			{/if}
			<!-- Refresh button -->
			<button
				onclick={refreshName}
				class="flex h-8 w-8 items-center justify-center rounded-full border-2 border-accent/20 text-accent/60 transition hover:border-accent/40 hover:text-accent hover:bg-white/60"
				title="Nouveau nom aléatoire"
				aria-label="Générer un nouveau nom"
			>
				<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
					<path d="M21.5 2v6h-6" />
					<path d="M2.5 22v-6h6" />
					<path d="M2.5 11.5a10 10 0 0 1 18.8-4.3" />
					<path d="M21.5 12.5a10 10 0 0 1-18.8 4.2" />
				</svg>
			</button>
		</div>
	</div>

	<!-- Upload area -->
	<button
		onclick={openPicker}
		class="flex w-full max-w-sm flex-col items-center justify-center gap-3 rounded-2xl border-2 border-dashed border-accent/30 bg-white/80 px-6 py-16 transition hover:border-accent/60"
	>
		<div
			class="flex h-12 w-12 items-center justify-center rounded-xl bg-accent text-2xl font-bold text-white"
		>
			+
		</div>
		<span class="text-accent/70">Ajouter des fichiers</span>
	</button>

	<input
		bind:this={fileInput}
		type="file"
		accept="image/*"
		multiple
		class="hidden"
		onchange={handleFiles}
	/>

	{#if uploading}
		<p class="mt-4 animate-pulse text-accent">Envoi en cours...</p>
	{/if}

	<!-- Uploaded images grid -->
	{#if uploadedImages.length > 0}
		<div class="mt-8 grid w-full max-w-sm grid-cols-2 gap-3">
			{#each uploadedImages as img (img.id)}
				<div class="group relative overflow-hidden rounded-xl bg-white shadow-md">
					<img
						src={imageUrl(img.path)}
						alt="upload"
						class="aspect-square w-full object-cover"
					/>
					<button
						onclick={() => removeImage(img)}
						class="absolute top-1.5 right-1.5 flex h-7 w-7 items-center justify-center rounded-full bg-dark/60 text-sm text-white opacity-0 transition group-hover:opacity-100"
						aria-label="Supprimer"
					>
						✕
					</button>
				</div>
			{/each}
		</div>
	{/if}
</div>
