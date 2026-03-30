import tailwindcss from '@tailwindcss/vite';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
	plugins: [
		tailwindcss(),
		sveltekit(),
		{
			name: 'remove-host-check',
			configureServer(server) {
				// Remove Vite's built-in host validation middleware from the stack
				const stack = server.middlewares.stack;
				const idx = stack.findIndex(
					(layer) => layer.handle && layer.handle.name === 'hostValidationMiddleware'
				);
				if (idx !== -1) stack.splice(idx, 1);
			}
		}
	],
	server: {
		proxy: {
			'/api': {
				target: 'http://backend:8000',
				changeOrigin: true
			}
		}
	}
});
