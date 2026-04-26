

export const index = 0;
let component_cache;
export const component = async () => component_cache ??= (await import('../entries/pages/_layout.svelte.js')).default;
export const universal = {
  "prerender": false,
  "ssr": false,
  "trailingSlash": "always"
};
export const universal_id = "src/routes/+layout.js";
export const imports = ["_app/immutable/nodes/0.Dqdv2UI4.js","_app/immutable/chunks/C_RCAzno.js","_app/immutable/chunks/D3vtQeQR.js","_app/immutable/chunks/CAy4USlN.js","_app/immutable/chunks/YAnJeKZs.js","_app/immutable/chunks/BYXb-ZWO.js","_app/immutable/chunks/DMi1Y-XH.js","_app/immutable/chunks/CDp2eCxF.js","_app/immutable/chunks/CAPIYpRg.js","_app/immutable/chunks/-MW3pwTB.js","_app/immutable/chunks/X-gFRinC.js"];
export const stylesheets = ["_app/immutable/assets/0.DVXKzpj0.css"];
export const fonts = [];
