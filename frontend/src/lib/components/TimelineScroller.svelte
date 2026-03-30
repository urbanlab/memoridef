<script lang="ts">
	import { appState } from '$lib/stores.svelte';

	let { availableDates = [] }: { availableDates?: string[] } = $props();

	const MAX_YEAR = new Date().getFullYear();
	const MIN_YEAR = 1990;

	let selectedYear = $derived(parseInt(appState.selectedDate.slice(0, 4)));
	let selectedMonth = $derived(parseInt(appState.selectedDate.slice(5, 7)));
	let selectedDay = $derived(parseInt(appState.selectedDate.slice(8, 10)));

	const monthNames = [
		'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
		'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
	];

	let displayDate = $derived(`${selectedDay} ${monthNames[selectedMonth - 1]}`);
	let topYear = $derived(Math.min(selectedYear + 1, MAX_YEAR));
	let bottomYear = $derived(Math.max(selectedYear - 1, MIN_YEAR));

	// Day-of-year progress for tick animation
	let dayOfYear = $derived.by(() => {
		const d = new Date(appState.selectedDate);
		const start = new Date(d.getFullYear(), 0, 0);
		return Math.floor((d.getTime() - start.getTime()) / 86400000);
	});
	let daysInYear = $derived.by(() => {
		const y = selectedYear;
		return (y % 4 === 0 && y % 100 !== 0) || y % 400 === 0 ? 366 : 365;
	});
	let yearProgress = $derived(dayOfYear / daysInYear);

	// Number of ticks per half (above center / below center)
	const TICK_COUNT = 14;

	// Each tick represents a day offset from the selected date.
	// Upper ticks: tick 0 (closest to center) = +1 day, tick TICK_COUNT-1 = +TICK_COUNT days
	// Lower ticks: tick 0 (closest to center) = -1 day, tick TICK_COUNT-1 = -TICK_COUNT days
	// We scale so the full half ≈ 365 days (one year span to reach the year labels)
	const DAYS_PER_HALF = 365;
	let daysPerTick = $derived(Math.round(DAYS_PER_HALF / TICK_COUNT));

	let availableDateSet = $derived(new Set(availableDates));

	let selectedDateMs = $derived(new Date(appState.selectedDate).getTime());

	function dayOffsetDate(offset: number): string {
		const d = new Date(selectedDateMs + offset * 86400000);
		return d.toISOString().slice(0, 10);
	}

	// Check if any day in the range covered by a tick has a photo
	function tickRangeHasPhoto(dayOffsetStart: number, dayOffsetEnd: number): boolean {
		const lo = Math.min(dayOffsetStart, dayOffsetEnd);
		const hi = Math.max(dayOffsetStart, dayOffsetEnd);
		for (let d = lo; d <= hi; d++) {
			if (availableDateSet.has(dayOffsetDate(d))) return true;
		}
		return false;
	}

	// Current selected date has a photo?
	let currentDayHasPhoto = $derived(availableDateSet.has(appState.selectedDate));

	function setYear(year: number) {
		const clamped = Math.max(MIN_YEAR, Math.min(MAX_YEAR, year));
		const m = selectedMonth.toString().padStart(2, '0');
		const maxDay = new Date(clamped, selectedMonth, 0).getDate();
		const d = Math.min(selectedDay, maxDay).toString().padStart(2, '0');
		appState.selectedDate = `${clamped}-${m}-${d}`;
	}

	function clampDate(d: Date): Date {
		const min = new Date(`${MIN_YEAR}-01-01`);
		const max = new Date(`${MAX_YEAR}-12-31`);
		return new Date(Math.max(min.getTime(), Math.min(max.getTime(), d.getTime())));
	}

	let accumDelta = 0;
	function handleWheel(e: WheelEvent) {
		e.preventDefault();
		accumDelta += e.deltaY;
		const step = 30;
		if (Math.abs(accumDelta) < step) return;
		const steps = Math.trunc(accumDelta / step);
		accumDelta -= steps * step;
		const current = new Date(appState.selectedDate);
		current.setDate(current.getDate() - steps);
		appState.selectedDate = clampDate(current).toISOString().slice(0, 10);
	}

	let dragStartY = 0;
	let dragStartDate = '';
	let isDragging = $state(false);

	function onPointerDown(e: PointerEvent) {
		isDragging = true;
		dragStartY = e.clientY;
		dragStartDate = appState.selectedDate;
		(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
	}

	function onPointerMove(e: PointerEvent) {
		if (!isDragging) return;
		const dy = e.clientY - dragStartY;
		const dayDelta = Math.round(dy / 8);
		if (dayDelta !== 0) {
			const base = new Date(dragStartDate);
			base.setDate(base.getDate() + dayDelta);
			appState.selectedDate = clampDate(base).toISOString().slice(0, 10);
		}
	}

	function onPointerUp() {
		isDragging = false;
	}
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
	class="flex h-full w-28 flex-col bg-white/60 select-none"
	onwheel={handleWheel}
	onpointerdown={onPointerDown}
	onpointermove={onPointerMove}
	onpointerup={onPointerUp}
	style="touch-action: none; cursor: ns-resize;"
>
	<!-- TOP: next year -->
	<button
		class="shrink-0 w-full pr-3 pt-3 pb-1 text-right text-xs text-dark/30 hover:text-dark/50 transition-colors"
		onclick={() => setYear(topYear)}
	>
		{topYear}
	</button>

	<!-- Upper ticks: future days (top = farthest, bottom = closest to center) -->
	<div class="flex flex-1 flex-col justify-end overflow-hidden pr-3">
		{#each Array(TICK_COUNT) as _, i}
			{@const tickIndex = TICK_COUNT - i}
			{@const dayStart = (tickIndex - 1) * daysPerTick + 1}
			{@const dayEnd = tickIndex * daysPerTick}
			{@const hasPhoto = tickRangeHasPhoto(dayStart, dayEnd)}
			{@const offset = yearProgress * (100 / (TICK_COUNT + 1))}
			<div
				class="flex w-full items-center justify-end gap-1.5"
				style="flex: 1; transform: translateY({offset}%);"
			>
				{#if hasPhoto}
					<div class="h-1.5 w-3 rounded-[1px] bg-accent/45"></div>
				{/if}
				<div class="h-px w-3 bg-dark/12"></div>
			</div>
		{/each}
	</div>

	<!-- CENTER: selected date + year -->
	<div class="flex w-full items-center justify-end px-2 py-2 shrink-0">
		{#if currentDayHasPhoto}
			<div class="h-2 w-3.5 rounded-[1px] bg-accent/60 mr-1.5"></div>
		{/if}
		<div class="flex flex-col items-end">
			<span class="text-[10px] leading-tight text-accent/70">{displayDate}</span>
			<span class="text-3xl font-black leading-none text-accent">{selectedYear}</span>
		</div>
		<span class="ml-1 text-lg text-accent">&#9664;</span>
	</div>

	<!-- Lower ticks: past days (top = closest to center, bottom = farthest) -->
	<div class="flex flex-1 flex-col overflow-hidden pr-3">
		{#each Array(TICK_COUNT) as _, i}
			{@const tickIndex = i + 1}
			{@const dayStart = -((tickIndex - 1) * daysPerTick + 1)}
			{@const dayEnd = -(tickIndex * daysPerTick)}
			{@const hasPhoto = tickRangeHasPhoto(dayStart, dayEnd)}
			{@const offset = yearProgress * (100 / (TICK_COUNT + 1))}
			<div
				class="flex w-full items-center justify-end gap-1.5"
				style="flex: 1; transform: translateY(-{offset}%);"
			>
				{#if hasPhoto}
					<div class="h-1.5 w-3 rounded-[1px] bg-accent/45"></div>
				{/if}
				<div class="h-px w-3 bg-dark/12"></div>
			</div>
		{/each}
	</div>

	<!-- BOTTOM: previous year -->
	<button
		class="shrink-0 w-full pr-3 pt-1 pb-3 text-right text-xs text-dark/30 hover:text-dark/50 transition-colors"
		onclick={() => setYear(bottomYear)}
	>
		{bottomYear}
	</button>
</div>
