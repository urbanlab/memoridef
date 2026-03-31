<script lang="ts">
	import { onMount } from 'svelte';

	interface InkDrop {
		x: number;
		y: number;
		r: number;
		g: number;
		b: number;
		seed: number;
		radius: number;
		birthTime: number;
	}

	let canvas = $state<HTMLCanvasElement>(undefined!);
	let gl: WebGLRenderingContext | null = null;
	let program: WebGLProgram | null = null;
	let animFrame: number;
	let startTime = Date.now();

	let drops: InkDrop[] = $state([]);

	const PALETTE = [
		[0.1, 0.2, 0.8],   // deep blue
		[0.7, 0.1, 0.3],   // crimson
		[0.2, 0.6, 0.4],   // teal
		[0.8, 0.5, 0.1],   // amber
		[0.5, 0.1, 0.7],   // purple
		[0.1, 0.5, 0.7],   // ocean
		[0.6, 0.3, 0.5],   // mauve
		[0.3, 0.7, 0.2],   // green
	];

	export function addDrop(x: number, y: number) {
		const color = PALETTE[Math.floor(Math.random() * PALETTE.length)];
		drops = [
			...drops,
			{
				x,
				y,
				r: color[0],
				g: color[1],
				b: color[2],
				seed: Math.random() * 100,
				radius: 0.12 + Math.random() * 0.06,
				birthTime: (Date.now() - startTime) / 1000.0
			}
		];
	}

	const VERT = `
		attribute vec2 a_position;
		void main() {
			gl_Position = vec4(a_position, 0.0, 1.0);
		}
	`;

	const FRAG = `
		precision mediump float;
		uniform vec2 u_resolution;
		uniform float u_time;
		uniform int u_count;
		uniform vec3 u_colors[32];
		uniform vec3 u_positions[32]; // x, y, radius
		uniform float u_seeds[32];
		uniform float u_birthTimes[32];

		float rand(vec2 n) {
			return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
		}

		float noise(vec2 p) {
			vec2 ip = floor(p);
			vec2 u = fract(p);
			u = u * u * (3.0 - 2.0 * u);
			float res = mix(
				mix(rand(ip), rand(ip + vec2(1.0, 0.0)), u.x),
				mix(rand(ip + vec2(0.0, 1.0)), rand(ip + vec2(1.0, 1.0)), u.x),
				u.y
			);
			return res * res;
		}

		const mat2 mtx = mat2(0.80, 0.60, -0.60, 0.80);

		float fbm(vec2 p, float seed) {
			float t = u_time * 0.15;
			float f = 0.0;
			p += seed;
			f += 0.500000 * noise(p + vec2(t, t * 0.7)); p = mtx * p * 2.02;
			f += 0.250000 * noise(p + vec2(t * 0.8, -t * 0.6)); p = mtx * p * 2.03;
			f += 0.125000 * noise(p + vec2(-t * 0.5, t * 0.9)); p = mtx * p * 2.01;
			f += 0.062500 * noise(p + vec2(t * 0.3, t * 0.4)); p = mtx * p * 2.04;
			f += 0.031250 * noise(p + vec2(sin(t), cos(t)));
			return f / 0.96875;
		}

		void main() {
			vec2 uv = gl_FragCoord.xy / u_resolution;
			uv.y = 1.0 - uv.y;
			float aspect = u_resolution.x / u_resolution.y;

			vec4 color = vec4(0.0);

			for (int i = 0; i < 32; i++) {
				if (i >= u_count) break;

				vec2 center = u_positions[i].xy;
				float maxRadius = u_positions[i].z;
				float seed = u_seeds[i];
				float age = u_time - u_birthTimes[i];
				// Grow from tiny to full over ~3 seconds with easeOut
				float growth = clamp(age / 3.0, 0.0, 1.0);
				growth = 1.0 - (1.0 - growth) * (1.0 - growth); // easeOutQuad
				float radius = mix(maxRadius * 0.05, maxRadius, growth);

				vec2 d = uv - center;
				d.x *= aspect;

				float dist = length(d);
				if (dist > radius * 2.0) continue;

				// Small turbulence displaces the distance field
				vec2 turbUv = d / radius * 4.0;
				float turb = fbm(turbUv, seed) - 0.5;

				// Displace the distance with turbulence for organic edges
				float displaced = dist + turb * radius * 0.7;

				// Solid circle with soft turbulent edge
				float inkShape = 1.0 - smoothstep(radius * 0.5, radius * 1.0, displaced);

				// Add subtle internal variation
				float interior = fbm(turbUv * 0.5 + 10.0, seed);
				inkShape *= 0.85 + interior * 0.15;

				float alpha = inkShape * 1.0;

				vec3 dropColor = u_colors[i];
				color.rgb = color.rgb * (1.0 - alpha) + dropColor * alpha;
				color.a = color.a * (1.0 - alpha) + alpha;
			}

			gl_FragColor = color;
		}
	`;

	function initGL() {
		if (!canvas) return;
		gl = canvas.getContext('webgl', { premultipliedAlpha: false, alpha: true });
		if (!gl) return;

		const vs = gl.createShader(gl.VERTEX_SHADER)!;
		gl.shaderSource(vs, VERT);
		gl.compileShader(vs);

		const fs = gl.createShader(gl.FRAGMENT_SHADER)!;
		gl.shaderSource(fs, FRAG);
		gl.compileShader(fs);

		if (!gl.getShaderParameter(fs, gl.COMPILE_STATUS)) {
			console.error('Fragment shader error:', gl.getShaderInfoLog(fs));
			return;
		}

		program = gl.createProgram()!;
		gl.attachShader(program, vs);
		gl.attachShader(program, fs);
		gl.linkProgram(program);

		if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
			console.error('Program link error:', gl.getProgramInfoLog(program));
			return;
		}

		const buf = gl.createBuffer();
		gl.bindBuffer(gl.ARRAY_BUFFER, buf);
		gl.bufferData(
			gl.ARRAY_BUFFER,
			new Float32Array([-1, -1, 1, -1, -1, 1, -1, 1, 1, -1, 1, 1]),
			gl.STATIC_DRAW
		);

		const loc = gl.getAttribLocation(program, 'a_position');
		gl.enableVertexAttribArray(loc);
		gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);

		gl.enable(gl.BLEND);
		gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
	}

	function render() {
		if (!gl || !program || !canvas) {
			animFrame = requestAnimationFrame(render);
			return;
		}

		const rect = canvas.parentElement?.getBoundingClientRect();
		if (rect) {
			const dpr = window.devicePixelRatio || 1;
			const w = Math.round(rect.width * dpr);
			const h = Math.round(rect.height * dpr);
			if (canvas.width !== w || canvas.height !== h) {
				canvas.width = w;
				canvas.height = h;
			}
		}

		gl.viewport(0, 0, canvas.width, canvas.height);
		gl.clearColor(0, 0, 0, 0);
		gl.clear(gl.COLOR_BUFFER_BIT);

		if (drops.length === 0) {
			animFrame = requestAnimationFrame(render);
			return;
		}

		gl.useProgram(program);

		gl.uniform2f(
			gl.getUniformLocation(program, 'u_resolution'),
			canvas.width,
			canvas.height
		);
		gl.uniform1f(
			gl.getUniformLocation(program, 'u_time'),
			(Date.now() - startTime) / 1000.0
		);

		const count = Math.min(drops.length, 32);
		gl.uniform1i(gl.getUniformLocation(program, 'u_count'), count);

		const colors: number[] = [];
		const positions: number[] = [];
		const seeds: number[] = [];
		const birthTimes: number[] = [];

		for (let i = 0; i < count; i++) {
			const d = drops[i];
			colors.push(d.r, d.g, d.b);
			positions.push(d.x, d.y, d.radius);
			seeds.push(d.seed);
			birthTimes.push(d.birthTime);
		}

		// Pad to 32
		for (let i = count; i < 32; i++) {
			colors.push(0, 0, 0);
			positions.push(0, 0, 0);
			seeds.push(0);
			birthTimes.push(0);
		}

		gl.uniform3fv(gl.getUniformLocation(program, 'u_colors'), colors);
		gl.uniform3fv(gl.getUniformLocation(program, 'u_positions'), positions);
		gl.uniform1fv(gl.getUniformLocation(program, 'u_seeds'), seeds);
		gl.uniform1fv(gl.getUniformLocation(program, 'u_birthTimes'), birthTimes);

		gl.drawArrays(gl.TRIANGLES, 0, 6);

		animFrame = requestAnimationFrame(render);
	}

	onMount(() => {
		initGL();
		animFrame = requestAnimationFrame(render);
		return () => {
			cancelAnimationFrame(animFrame);
		};
	});
</script>

<canvas
	bind:this={canvas}
	class="absolute inset-0 z-20 h-full w-full pointer-events-none"
	style="mix-blend-mode: multiply;"
></canvas>
