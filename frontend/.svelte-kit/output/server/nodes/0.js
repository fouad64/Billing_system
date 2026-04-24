

export const index = 0;
let component_cache;
export const component = async () => component_cache ??= (await import('../entries/pages/_layout.svelte.js')).default;
export const universal = {
  "prerender": false,
  "ssr": false,
  "trailingSlash": "always"
};
export const universal_id = "src/routes/+layout.js";
export const imports = ["_app/immutable/nodes/0.BZIcbnkh.js","_app/immutable/chunks/CbtuN0cd.js","_app/immutable/chunks/UNZZCu5_.js","_app/immutable/chunks/Dro05P0n.js","_app/immutable/chunks/U0L0euFV.js","_app/immutable/chunks/WdrG5ig7.js","_app/immutable/chunks/CZbI-x8T.js","_app/immutable/chunks/D70ND7Hs.js","_app/immutable/chunks/jp_7ZZFV.js","_app/immutable/chunks/CqRVYgKE.js","_app/immutable/chunks/Bdq_RrVz.js"];
export const stylesheets = ["_app/immutable/assets/0.CAzD903r.css"];
export const fonts = [];
