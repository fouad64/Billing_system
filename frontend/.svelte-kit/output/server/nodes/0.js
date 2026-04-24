

export const index = 0;
let component_cache;
export const component = async () => component_cache ??= (await import('../entries/pages/_layout.svelte.js')).default;
export const universal = {
  "prerender": false,
  "ssr": false,
  "trailingSlash": "always"
};
export const universal_id = "src/routes/+layout.js";
export const imports = ["_app/immutable/nodes/0.BqJEwamh.js","_app/immutable/chunks/BAry0p6x.js","_app/immutable/chunks/Bg2E0iCm.js","_app/immutable/chunks/BMg6UULY.js","_app/immutable/chunks/CTNTokNZ.js","_app/immutable/chunks/BjY1qIhZ.js","_app/immutable/chunks/C_Kt1-qY.js","_app/immutable/chunks/Cx_afglr.js","_app/immutable/chunks/CVrVh0hI.js","_app/immutable/chunks/D2qHlwWe.js","_app/immutable/chunks/KwJHjKCn.js"];
export const stylesheets = ["_app/immutable/assets/0.C43Ud9rj.css"];
export const fonts = [];
