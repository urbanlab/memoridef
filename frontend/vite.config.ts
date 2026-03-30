import tailwindcss from '@tailwindcss/vite';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig, type Plugin } from 'vite';

function allowAllHosts(): Plugin {
	return {
		name: 'allow-all-hosts',
		configResolved(config) {
			// Force allowedHosts to true after all plugins have merged their config
			(config.server as any).allowedHosts = true;
		}
	};
}

export default defineConfig({
	plugins: [tailwindcss(), sveltekit(), allowAllHosts()],
	server: {
		host: true,
		proxy: {
			'/api': {
				target: 'http://backend:8000',
				changeOrigin: true
			}
		}
	}
});
