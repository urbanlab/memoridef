import tailwindcss from '@tailwindcss/vite';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig, mergeConfig } from 'vite';

const config = defineConfig({
	plugins: [tailwindcss(), sveltekit()],
	server: {
		proxy: {
			'/api': {
				target: 'http://backend:8000',
				changeOrigin: true
			}
		}
	}
});

export default mergeConfig(config, {
	server: {
		allowedHosts: ['memoridef.projets.erasme.org']
	}
});
