import { h as head, a as attr, c as ensure_array_like, e as escape_html } from "../../../../chunks/renderer.js";
function _page($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    let customers = [];
    let search = "";
    head("zvcdha", $$renderer2, ($$renderer3) => {
      $$renderer3.title(($$renderer4) => {
        $$renderer4.push(`<title>Customers — FMRZ</title>`);
      });
    });
    $$renderer2.push(`<div class="container"><div class="page-header"><h1>Customer <span class="text-gradient">Directory</span></h1> <p class="text-muted">Manage subscriber profiles and account information</p></div> <div class="search-bar animate-fade"><div style="display:flex;gap:1rem"><div class="relative group" style="position: relative;"><span style="position: absolute; left: 12px; top: 50%; transform: translateY(-50%); color: #64748b;"><svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"></circle><path d="m21 21-4.3-4.3"></path></svg></span> <input class="input" style="width:300px; padding-left: 2.5rem;" placeholder="Search directory..."${attr("value", search)} aria-label="Search customers"/></div> <button class="btn btn-primary" style="display: flex; align-items: center; gap: 8px; padding: 0.75rem 1.5rem;"><svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14"></path><path d="M12 5v14"></path></svg> Add New Customer</button></div></div> <div class="table-wrapper static-table animate-fade svelte-zvcdha"><table class="svelte-zvcdha"><thead><tr><th class="svelte-zvcdha">ID</th><th class="svelte-zvcdha">MSISDN</th><th class="svelte-zvcdha">Name</th><th class="svelte-zvcdha">Email</th><th class="svelte-zvcdha">Address</th><th class="svelte-zvcdha">Birthdate</th></tr></thead><tbody><!--[-->`);
    const each_array = ensure_array_like(customers);
    for (let $$index = 0, $$length = each_array.length; $$index < $$length; $$index++) {
      let c = each_array[$$index];
      $$renderer2.push(`<tr class="svelte-zvcdha"><td class="svelte-zvcdha"><span class="id-badge svelte-zvcdha">#${escape_html(c.id)}</span></td><td class="svelte-zvcdha"><span class="phone-num svelte-zvcdha" style="color: var(--red) !important;">${escape_html(c.msisdn)}</span></td><td class="customer-name svelte-zvcdha" style="color: #FFFFFF !important;">${escape_html(c.name)}</td><td style="color: #94A3B8 !important; font-size: 0.9rem; font-weight: 500;" class="svelte-zvcdha">${escape_html(c.email || "—")}</td><td style="color: #FB7185 !important; font-size: 0.9rem; font-weight: 500;" class="svelte-zvcdha">${escape_html(c.address || "—")}</td><td style="color: #64748B !important; font-size: 0.9rem; font-weight: 600;" class="svelte-zvcdha">${escape_html(c.birthdate || "—")}</td></tr>`);
    }
    $$renderer2.push(`<!--]--></tbody></table></div></div> `);
    {
      $$renderer2.push("<!--[-1-->");
    }
    $$renderer2.push(`<!--]--> `);
    {
      $$renderer2.push("<!--[-1-->");
    }
    $$renderer2.push(`<!--]-->`);
  });
}
export {
  _page as default
};
