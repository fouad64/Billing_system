

export const index = 0;
let component_cache;
export const component = async () => component_cache ??= (await import('../entries/pages/_layout.svelte.js')).default;
export const universal = {
  "prerender": false,
  "ssr": false,
  "trailingSlash": "always"
};
export const universal_id = "src/routes/+layout.js";
export const imports = ["_app/immutable/nodes/0.9cS7Ls1R.js","_app/immutable/chunks/BmANHQm3.js","_app/immutable/chunks/D3-p0Llo.js","_app/immutable/chunks/BQ4oqq0J.js","_app/immutable/chunks/CgF1_Pmg.js","_app/immutable/chunks/BpJCQAtH.js","_app/immutable/chunks/BIk7BDf8.js","_app/immutable/chunks/Dpg4fMt8.js","_app/immutable/chunks/31LdlxM9.js","_app/immutable/chunks/BHKwrhHI.js","_app/immutable/chunks/CMckTnuI.js"];
export const stylesheets = ["_app/immutable/assets/0.DVXKzpj0.css"];
export const fonts = [];
