import type { ImageData } from './api';

export interface DragState {
	image: ImageData;
	source: 'carousel' | 'map';
	/** Current pointer position (client coords) */
	x: number;
	y: number;
	/** Start position */
	startX: number;
	startY: number;
	/** Has the pointer moved enough to be a real drag */
	active: boolean;
}

export const appState = $state({
	selectedDate: new Date().toISOString().slice(0, 10),
	placedImages: [] as ImageData[],
	carouselImages: [] as ImageData[],
	availableDates: [] as string[],
	drag: null as DragState | null
});

const DRAG_THRESHOLD = 6; // px before drag becomes active

export function beginDrag(e: PointerEvent, image: ImageData, source: 'carousel' | 'map') {
	// Prevent default to avoid text selection, image ghost, etc.
	e.preventDefault();
	appState.drag = {
		image,
		source,
		x: e.clientX,
		y: e.clientY,
		startX: e.clientX,
		startY: e.clientY,
		active: false
	};
}

export function moveDrag(e: PointerEvent) {
	const drag = appState.drag;
	if (!drag) return;
	drag.x = e.clientX;
	drag.y = e.clientY;
	if (!drag.active) {
		const dx = drag.x - drag.startX;
		const dy = drag.y - drag.startY;
		if (Math.sqrt(dx * dx + dy * dy) >= DRAG_THRESHOLD) {
			drag.active = true;
		}
	}
}

export function endDrag(): DragState | null {
	const drag = appState.drag;
	appState.drag = null;
	return drag;
}

/** Returns true if a drag was recently active (to suppress click) */
let lastDragEndTime = 0;
export function wasDragging(): boolean {
	return Date.now() - lastDragEndTime < 100;
}

export function markDragEnd() {
	lastDragEndTime = Date.now();
}
