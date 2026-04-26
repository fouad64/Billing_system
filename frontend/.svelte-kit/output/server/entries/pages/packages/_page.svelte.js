import { h as head } from "../../../chunks/renderer.js";
function _page($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    head("disfw2", $$renderer2, ($$renderer3) => {
      $$renderer3.title(($$renderer4) => {
        $$renderer4.push(`<title>Packages — FMRZ</title>`);
      });
    });
    $$renderer2.push(`<div class="container"><div class="page-header"><div><h1>Rate Plans &amp; <span class="text-gradient">Packages</span></h1> <p class="page-subtitle">Choose the perfect plan for your communication needs</p></div></div> `);
    {
      $$renderer2.push("<!--[0-->");
      $$renderer2.push(`<div class="loading">Loading...</div>`);
    }
    $$renderer2.push(`<!--]--></div>`);
  });
}
export {
  _page as default
};
