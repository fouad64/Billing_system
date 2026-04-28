

export const index = 0;
let component_cache;
export const component = async () => component_cache ??= (await import('../entries/pages/_layout.svelte.js')).default;
export const universal = {
  "prerender": false,
  "ssr": false,
  "trailingSlash": "always"
};
export const universal_id = "src/routes/+layout.js";
export const imports = ["_app/immutable/nodes/0.Dwzjmjah.js","_app/immutable/chunks/CpwPv4cv.js","_app/immutable/chunks/D5SiFdjx.js","_app/immutable/chunks/Bxip-a9u.js","_app/immutable/chunks/BKZKjyOh.js","_app/immutable/chunks/ec7sGkDg.js","_app/immutable/chunks/BPkgh1IZ.js","_app/immutable/chunks/BS8h2ajm.js","_app/immutable/chunks/BKuqSeVd.js","_app/immutable/chunks/-yBZH9BG.js","_app/immutable/chunks/DZhBzM_d.js","_app/immutable/chunks/stCOaEVK.js"];
export const stylesheets = ["_app/immutable/assets/0.ju5NWwKN.css"];
export const fonts = [];
