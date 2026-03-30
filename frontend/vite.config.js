import tailwindcss from '@tailwindcss/vite';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
	plugins: [
		tailwindcss(),
		sveltekit(),
		{
			name: 'bypass-host-check',
			configureServer(server) {
				server.middlewares.use((req, res, next) => {
					req.headers.host = 'localhost';
					next();
				});
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
