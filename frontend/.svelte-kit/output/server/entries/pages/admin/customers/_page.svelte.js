import { h as head, a as attr, d as ensure_array_like, e as escape_html } from "../../../../chunks/renderer.js";
function _page($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    let customers = [];
    let search = "";
    head("zvcdha", $$renderer2, ($$renderer3) => {
      $$renderer3.title(($$renderer4) => {
        $$renderer4.push(`<title>Customers — FMRZ Admin</title>`);
      });
    });
    $$renderer2.push(`<div class="container"><div class="page-header"><h1>Customer <span class="text-gradient">Directory</span></h1> <p class="text-muted">Manage subscriber profiles and account information</p></div> <div class="search-bar animate-fade"><div style="display:flex;gap:1rem"><div class="relative group" style="position: relative;"><span style="position: absolute; left: 12px; top: 50%; transform: translateY(-50%); color: #64748b;"><svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"></circle><path d="m21 21-4.3-4.3"></path></svg></span> <input class="input" style="width:300px; padding-left: 2.5rem;" placeholder="Search directory..."${attr("value", search)} aria-label="Search customers"/></div> <button class="btn btn-primary" style="display: flex; align-items: center; gap: 8px; padding: 0.75rem 1.5rem;"><svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14"></path><path d="M12 5v14"></path></svg> Add New Customer</button></div></div> <div class="table-wrapper card card-static animate-fade svelte-zvcdha" style="margin-top: 2rem; border: 1px solid var(--border); border-radius: 20px; overflow: hidden;"><table style="border: none;"><thead><tr><th>ID</th><th>MSISDN</th><th>Name</th><th>Email</th><th>Address</th><th>Birthdate</th></tr></thead><tbody><!--[-->`);
    const each_array = ensure_array_like(customers);
    for (let $$index = 0, $$length = each_array.length; $$index < $$length; $$index++) {
      let c = each_array[$$index];
      $$renderer2.push(`<tr><td><span class="id-badge svelte-zvcdha">#${escape_html(c.id)}</span></td><td><span class="phone-num">${escape_html(c.msisdn)}</span></td><td class="customer-name">${escape_html(c.name)}</td><td class="meta-info">${escape_html(c.email || "—")}</td><td class="meta-info">${escape_html(c.address || "—")}</td><td class="meta-info">${escape_html(c.birthdate || "—")}</td></tr>`);
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
