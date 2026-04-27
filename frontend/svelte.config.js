import adapter from '@sveltejs/adapter-static';

const isProd = process.env.VERCEL === '1';

/** @type {import('@sveltejs/kit').Config} */
const config = {
	kit: {
		adapter: adapter({
			pages:       isProd ? 'build' : '../src/main/webapp',
			assets:      isProd ? 'build' : '../src/main/webapp',
			fallback:    'index.html',
			precompress: false,
			strict:      true
		}),
		paths: {
			base: ""
		}
	}
};

export default config;