

export const index = 6;
let component_cache;
export const component = async () => component_cache ??= (await import('../entries/pages/admin/contracts/_page.svelte.js')).default;
export const imports = ["_app/immutable/nodes/6.C0krgGoX.js","_app/immutable/chunks/CbtuN0cd.js","_app/immutable/chunks/UNZZCu5_.js","_app/immutable/chunks/DDwrF6VY.js","_app/immutable/chunks/DXO2rSEH.js","_app/immutable/chunks/D70ND7Hs.js"];
export const stylesheets = [];
export const fonts = [];
