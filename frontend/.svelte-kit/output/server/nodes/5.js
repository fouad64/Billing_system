

export const index = 5;
let component_cache;
export const component = async () => component_cache ??= (await import('../entries/pages/admin/contracts/_page.svelte.js')).default;
export const imports = ["_app/immutable/nodes/5.2Ad1Yd0N.js","_app/immutable/chunks/BAry0p6x.js","_app/immutable/chunks/Bg2E0iCm.js","_app/immutable/chunks/C-4VD3dT.js","_app/immutable/chunks/BfI24Z5g.js","_app/immutable/chunks/Cx_afglr.js"];
export const stylesheets = [];
export const fonts = [];
