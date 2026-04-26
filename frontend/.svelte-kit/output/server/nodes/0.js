

export const index = 0;
let component_cache;
export const component = async () => component_cache ??= (await import('../entries/pages/_layout.svelte.js')).default;
export const universal = {
  "prerender": false,
  "ssr": false,
  "trailingSlash": "always"
};
export const universal_id = "src/routes/+layout.js";
export const imports = ["_app/immutable/nodes/0.DvQ4Dldu.js","_app/immutable/chunks/C5ujjk74.js","_app/immutable/chunks/87bIvZSd.js","_app/immutable/chunks/D46fgPKJ.js","_app/immutable/chunks/DJBmNonr.js","_app/immutable/chunks/RAoeSuPI.js","_app/immutable/chunks/DIheLVo_.js","_app/immutable/chunks/CbKy6h33.js","_app/immutable/chunks/B08B5jt4.js","_app/immutable/chunks/C2aUmeH-.js","_app/immutable/chunks/Cg4rezI7.js","_app/immutable/chunks/CVvJ1TDU.js"];
export const stylesheets = ["_app/immutable/assets/0.BwHT5f8w.css"];
export const fonts = [];
