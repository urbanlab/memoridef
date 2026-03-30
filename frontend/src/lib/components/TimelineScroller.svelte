<script lang="ts">
	import { appState } from '$lib/stores.svelte';

	let { availableDates = [] }: { availableDates?: string[] } = $props();

	const currentYear = new Date().getFullYear();
	const startYear = 1990;
	const years = Array.from({ length: currentYear - startYear + 1 }, (_, i) => startYear + i);

	let selectedYear = $derived(parseInt(appState.selectedDate.slice(0, 4)));
	let selectedMonth = $derived(parseInt(appState.selectedDate.slice(5, 7)));
	let selectedDay = $derived(parseInt(appState.selectedDate.slice(8, 10)));

	const monthNames = [
		'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
		'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
	];

	let displayDate = $derived(`${selectedDay} ${monthNames[selectedMonth - 1]}`);

	// Dragging state
	let isDragging = $state(false);
	let timelineEl: HTMLDivElement;

	function jumpToYear(year: number) {
		const m = selectedMonth.toString().padStart(2, '0');
		const d = selectedDay.toString().padStart(2, '0');
		appState.selectedDate = `${year}-${m}-${d}`;
	}

	// Handle drag along timeline to scrub year
	function handlePointerDown(e: PointerEvent) {
		isDragging = true;
		(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
		updateYearFromPointer(e);
	}

	function handlePointerMove(e: PointerEvent) {
		if (!isDragging) return;
		updateYearFromPointer(e);
	}

	function handlePointerUp() {
		isDragging = false;
	}

	function updateYearFromPointer(e: PointerEvent) {
		if (!timelineEl) return;
		const rect = timelineEl.getBoundingClientRect();
		const ratio = 1 - (e.clientY - rect.top) / rect.height;
		const clamped = Math.max(0, Math.min(1, ratio));
		const year = Math.round(startYear + clamped * (currentYear - startYear));
		jumpToYear(year);
	}

	// Scroll wheel on timeline changes day
	function handleWheel(e: WheelEvent) {
		e.preventDefault();
		const current = new Date(appState.selectedDate);
		current.setDate(current.getDate() + (e.deltaY > 0 ? -1 : 1));
		appState.selectedDate = current.toISOString().slice(0, 10);
	}

	// Number of tick marks between each year label
	const TICKS_PER_YEAR = 4;
</script>

<div
	class="timeline-container flex h-full w-24 flex-col items-end bg-white/60"
	onwheel={handleWheel}
>
	<!-- Year timeline -->
	<div
		bind:this={timelineEl}
		class="relative flex flex-1 w-full flex-col justify-between py-4 pr-2 cursor-ns-resize select-none"
		onpointerdown={handlePointerDown}
		onpointermove={handlePointerMove}
		onpointerup={handlePointerUp}
		role="slider"
		aria-label="Timeline"
		aria-valuemin={startYear}
		aria-valuemax={currentYear}
		aria-valuenow={selectedYear}
		tabindex="0"
	>
		{#each years.toReversed() as year, i}
			{@const isSelected = year === selectedYear}

			<!-- Year label -->
			<div class="relative flex w-full items-center justify-end">
				<!-- Tick line -->
				<div class="h-px flex-1 {isSelected ? 'bg-accent' : 'bg-dark/15'}"></div>

				<!-- Year text -->
				<span
					class="pl-1 text-right font-mono leading-none transition-all whitespace-nowrap {isSelected
						? 'text-sm font-black text-accent'
						: 'text-[10px] text-dark/30'}"
				>
					{year}
				</span>
			</div>

			<!-- Selected year callout -->
			{#if isSelected}
				<div class="flex w-full items-center justify-end pr-0 -my-1">
					<div class="flex flex-col items-end mr-0">
						<span class="text-[10px] text-accent/70 leading-tight">{displayDate}</span>
						<span class="text-3xl font-black text-accent leading-none">{year}</span>
					</div>
					<span class="text-accent text-lg ml-0.5">&#9664;</span>
				</div>
			{/if}

			<!-- Small tick marks between years -->
			{#if i < years.length - 1}
				{#each Array(TICKS_PER_YEAR) as _}
					<div class="flex w-full items-center justify-end">
						<div class="h-px w-2 bg-dark/10"></div>
					</div>
				{/each}
			{/if}
		{/each}
	</div>
</div>
