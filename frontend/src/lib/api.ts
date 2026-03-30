const BASE = '';

export interface ImageData {
	id: number;
	author: string;
	upload_date: string;
	date: string | null;
	path: string;
	location_x: number | null;
	location_y: number | null;
}

export interface UploadResponse {
	session_id: string;
	author: string;
	images: ImageData[];
}

export async function fetchImages(dateFrom?: string, dateTo?: string): Promise<ImageData[]> {
	const params = new URLSearchParams();
	if (dateFrom) params.set('date_from', dateFrom);
	if (dateTo) params.set('date_to', dateTo);
	const res = await fetch(`${BASE}/api/images?${params}`);
	return res.json();
}

export async function fetchUnplacedImages(): Promise<ImageData[]> {
	const res = await fetch(`${BASE}/api/images/unplaced`);
	return res.json();
}

export async function uploadFiles(
	files: FileList | File[],
	sessionId?: string
): Promise<UploadResponse> {
	const form = new FormData();
	for (const f of files) {
		form.append('files', f);
	}
	const params = sessionId ? `?session_id=${sessionId}` : '';
	const res = await fetch(`${BASE}/api/upload${params}`, {
		method: 'POST',
		body: form
	});
	return res.json();
}

export async function updateImage(
	id: number,
	data: { date?: string; location_x?: number; location_y?: number }
): Promise<ImageData> {
	const res = await fetch(`${BASE}/api/images/${id}`, {
		method: 'PUT',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify(data)
	});
	return res.json();
}

export async function deleteImage(id: number): Promise<void> {
	await fetch(`${BASE}/api/images/${id}`, { method: 'DELETE' });
}

export async function fetchDatesWithImages(): Promise<string[]> {
	const res = await fetch(`${BASE}/api/dates`);
	return res.json();
}

export function imageUrl(path: string): string {
	return `${BASE}/api/uploads/${path}`;
}

export async function renameSession(
	sessionId: string,
	author: string
): Promise<{ session_id: string; author: string }> {
	const res = await fetch(`${BASE}/api/sessions/${sessionId}/rename`, {
		method: 'PUT',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ author })
	});
	return res.json();
}

export async function randomizeSessionName(
	sessionId: string
): Promise<{ session_id: string; author: string }> {
	const res = await fetch(`${BASE}/api/sessions/${sessionId}/randomize-name`, {
		method: 'POST'
	});
	return res.json();
}

export async function fetchRandomName(): Promise<string> {
	const res = await fetch(`${BASE}/api/random-name`);
	const data = await res.json();
	return data.name;
}
