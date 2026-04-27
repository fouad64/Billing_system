

export const index = 0;
let component_cache;
export const component = async () => component_cache ??= (await import('../entries/pages/_layout.svelte.js')).default;
export const universal = {
  "prerender": false,
  "ssr": false,
  "trailingSlash": "always"
};
export const universal_id = "src/routes/+layout.js";
export const imports = ["_app/immutable/nodes/0.nlAgAmJx.js","_app/immutable/chunks/Cnri5IQm.js","_app/immutable/chunks/alBkrSSP.js","_app/immutable/chunks/BhmXjptP.js","_app/immutable/chunks/BX6sDNQ4.js","_app/immutable/chunks/DzQ3cZIB.js","_app/immutable/chunks/CRW4d5i-.js","_app/immutable/chunks/CYVjqzzc.js","_app/immutable/chunks/BKuqSeVd.js","_app/immutable/chunks/COMZgjBA.js","_app/immutable/chunks/D4sjK7LV.js","_app/immutable/chunks/CVxNEjHX.js"];
export const stylesheets = ["_app/immutable/assets/0.CFpzGuBL.css"];
export const fonts = [];
