import { h as head } from "../../../chunks/renderer.js";
import "../../../chunks/client.js";
function _page($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    head("disfw2", $$renderer2, ($$renderer3) => {
      $$renderer3.title(($$renderer4) => {
        $$renderer4.push(`<title>Packages — FMRZ</title>`);
      });
    });
    $$renderer2.push(`<div class="container">`);
    {
      $$renderer2.push("<!--[-1-->");
    }
    $$renderer2.push(`<!--]--> `);
    {
      $$renderer2.push("<!--[-1-->");
    }
    $$renderer2.push(`<!--]--> <div class="page-header"><div><h1>Rate Plans &amp; <span class="text-gradient">Packages</span></h1> <p class="page-subtitle">Premium communication solutions tailored for the digital age</p></div></div> `);
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
