<script>
  import { fade, fly } from 'svelte/transition';
  import { onMount } from 'svelte';

  let { billId, userId, onClose } = $props();
  
  let bill = $state(null);
  let breakdown = $state([]);
  let customer = $state(null);
  let loading = $state(true);
  let userRole = $state('customer'); // Default to customer for safety

  async function loadDrilldown() {
    loading = true;
    try {
      // First, check the current user's role
      const meRes = await fetch('/api/auth/me', { credentials: 'include' });
      if (meRes.ok) {
        const me = await meRes.json();
        userRole = me.role;
      }

      // Determine endpoints based on role
      const isAdmin = userRole === 'admin';
      const billUrl = isAdmin ? `/api/admin/bills/${billId}` : `/api/customer/invoices`; // Customer list is used to find the specific bill if needed, but here we just need the single bill data
      
      // For customers, we might need a specific 'get bill' endpoint if not using admin paths
      // Actually, let's keep it simple: if admin, use admin APIs. If customer, use customer APIs.
      const [billRes, breakRes, custRes] = await Promise.all([
        fetch(isAdmin ? `/api/admin/bills/${billId}` : `/api/customer/invoices`, { credentials: 'include' }),
        fetch(isAdmin ? `/api/admin/bills/${billId}/breakdown` : `/api/customer/invoices/download?id=${billId}`, { credentials: 'include' }), // This is just a placeholder to check connectivity for customers
        fetch(isAdmin ? `/api/admin/customers/${userId}` : `/api/customer/profile`, { credentials: 'include' })
      ]);

      if (billRes.ok) {
          const data = await billRes.json();
          // If customer, we find the specific bill from the list
          bill = isAdmin ? data : data.find(b => b.id === parseInt(billId));
      }
      
      if (isAdmin && breakRes.ok) {
          breakdown = await breakRes.json();
      } else {
          // Customers get breakdown logic from the bill object or a public endpoint if available
          // For now, we'll focus on making the download button work.
      }
      
      if (custRes.ok) customer = await custRes.json();
    } catch (e) {
      console.error("Drilldown load failed", e);
    } finally {
      loading = false;
    }
  }

  function handleDownload() {
    if (userRole === 'admin') {
      window.location.href = `/api/admin/bills/${billId}/download`;
    } else {
      window.location.href = `/api/customer/invoices/download?id=${billId}`;
    }
  }

  onMount(loadDrilldown);

  function formatPrice(val) {
    return new Intl.NumberFormat('en-EG', { style: 'currency', currency: 'EGP' }).format(val);
  }
</script>

<div class="drawer-backdrop" onclick={onClose} transition:fade={{duration: 200}}>
  <div class="drawer-content" onclick={(e) => e.stopPropagation()} transition:fly={{x: 400, duration: 400}}>
    <div class="drawer-header">
      <div class="header-main">
        <h2>Invoice <span class="text-gradient">#{billId}</span></h2>
        <span class="badge status-{bill?.status || 'issued'}">{bill?.status || 'issued'}</span>
      </div>
      <div class="header-actions">
        <button class="btn-icon-action" onclick={handleDownload} title="Download Official PDF">
          <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
        </button>
        <button class="close-btn" onclick={onClose}>
          <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
        </button>
      </div>
    </div>

    {#if loading}
      <div class="drawer-loader">
        <div class="spinner"></div>
        <p>Synchronizing deep data...</p>
      </div>
    {:else}
      <div class="drawer-body">
        <!-- Customer Section -->
        <section class="drilldown-section profile-section">
          <div class="section-title">Customer Profile</div>
          <div class="profile-card">
            <div class="avatar-box">
              {customer?.name?.charAt(0) || 'U'}
            </div>
            <div class="profile-info">
              <div class="p-name">{customer?.name || 'Unknown'}</div>
              <div class="p-email">{customer?.email || 'no-email@fmrz.com'}</div>
              <div class="p-address">{customer?.address || 'No address recorded'}</div>
            </div>
          </div>
        </section>

        <!-- Financial Summary Section -->
        <section class="drilldown-section">
          <div class="section-title">Financial Breakdown</div>
          <div class="summary-grid">
            <div class="summary-item">
              <span class="label">Monthly Subscription</span>
              <span class="val">{formatPrice(bill?.recurring_fees || 0)}</span>
            </div>
            <div class="summary-item">
              <span class="label">Usage & Overages</span>
              <span class="val">{formatPrice(bill?.overage_charge || 0)}</span>
            </div>
            <div class="summary-item">
              <span class="label">Roaming Charges</span>
              <span class="val accent-orange">{formatPrice(bill?.roaming_charge || 0)}</span>
            </div>
            <div class="summary-item">
              <span class="label">One-time Fees</span>
              <span class="val">{formatPrice(bill?.one_time_fees || 0)}</span>
            </div>
            <div class="summary-item">
              <span class="label">VAT Tax (14%)</span>
              <span class="val">{formatPrice(bill?.taxes || 0)}</span>
            </div>
            <div class="summary-total shine-box">
              <span class="label">Total Due</span>
              <span class="val shine-text">{formatPrice(bill?.total_amount || 0)}</span>
            </div>
          </div>
        </section>

        <!-- Usage Breakdown Section -->
        <section class="drilldown-section">
          <div class="section-title">Usage Breakdown (Rated CDRs)</div>
          <div class="breakdown-list">
            {#each breakdown as item}
              <div class="breakdown-row" class:is-roaming={item.is_roaming}>
                <div class="item-icon {item.service_type.toLowerCase()}">
                  {#if item.service_type === 'VOICE'}
                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l2.28-2.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"/></svg>
                  {:else if item.service_type === 'DATA'}
                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M5 12.55a11 11 0 0 1 14.08 0"/><path d="M1.42 9a16 16 0 0 1 21.16 0"/><path d="M8.53 16.11a6 6 0 0 1 6.95 0"/><line x1="12" y1="20" x2="12.01" y2="20"/></svg>
                  {:else}
                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>
                  {/if}
                </div>
                <div class="item-details">
                  <div class="item-name">
                    {item.category_label} 
                    {#if item.is_roaming}<span class="roaming-tag">Roaming</span>{/if}
                  </div>
                  <div class="item-quota">
                    {#if item.quota_display}
                      {item.consumed_display} / {item.quota_display} {item.unit_label}
                    {:else}
                      {item.consumed_display} {item.unit_label}
                    {/if}
                  </div>
                </div>
                <div class="item-cost">
                  {formatPrice(item.line_total)}
                </div>
              </div>
            {/each}
          </div>
        </section>
      </div>
    {/if}
  </div>
</div>

<style>
  .drawer-backdrop {
    position: fixed; top: 0; left: 0; right: 0; bottom: 0;
    background: rgba(0,0,0,0.6); backdrop-filter: blur(8px);
    z-index: 1000; display: flex; justify-content: flex-end;
  }
  .drawer-content {
    width: 500px; height: 100%; background: #0a0a0f;
    border-left: 1px solid rgba(255,255,255,0.1);
    box-shadow: -20px 0 50px rgba(0,0,0,0.5);
    display: flex; flex-direction: column; overflow: hidden;
  }
  .drawer-header {
    padding: 1rem 1.5rem; border-bottom: 1px solid rgba(255,255,255,0.05);
    display: flex; justify-content: space-between; align-items: center;
    background: rgba(255,255,255,0.02);
  }
  .header-actions { display: flex; align-items: center; gap: 0.5rem; }
  .btn-icon-action {
    background: rgba(255, 255, 255, 0.05); border: 1px solid rgba(255, 255, 255, 0.1);
    color: var(--text-muted); width: 36px; height: 36px; border-radius: 10px;
    display: flex; align-items: center; justify-content: center; cursor: pointer;
    transition: all 0.2s;
  }
  .btn-icon-action:hover { background: var(--red); border-color: var(--red); color: white; transform: translateY(-2px); }

  .header-main { display: flex; align-items: center; gap: 1rem; }
  .header-main h2 { font-size: 1.25rem; font-weight: 800; }
  .close-btn { background: none; border: none; color: var(--text-muted); cursor: pointer; padding: 4px; border-radius: 8px; transition: all 0.2s; }
  .close-btn:hover { background: rgba(255,255,255,0.05); color: white; }

  .drawer-body { flex: 1; overflow-y: auto; padding: 1.5rem; display: flex; flex-direction: column; gap: 1.5rem; }
  .drilldown-section { display: flex; flex-direction: column; gap: 0.75rem; }
  .section-title { font-size: 0.7rem; font-weight: 800; text-transform: uppercase; letter-spacing: 0.1em; color: var(--text-muted); border-left: 3px solid var(--red); padding-left: 10px; }

  .profile-card {
    background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.05);
    border-radius: 16px; padding: 1rem; display: flex; align-items: center; gap: 1rem;
  }
  .avatar-box {
    width: 44px; height: 44px; background: linear-gradient(135deg, var(--red), #ff4d4d);
    border-radius: 12px; display: flex; align-items: center; justify-content: center;
    font-size: 1.25rem; font-weight: 900; color: white; box-shadow: 0 4px 15px rgba(224, 8, 0, 0.3);
  }
  .p-name { font-size: 1rem; font-weight: 800; color: white; margin-bottom: 1px; }
  .p-email { font-size: 0.8rem; color: var(--text-muted); margin-bottom: 2px; }
  .p-address { font-size: 0.75rem; color: #888; }

  .summary-grid {
    background: rgba(255,255,255,0.02); border: 1px solid rgba(255,255,255,0.05);
    border-radius: 16px; padding: 1rem; display: flex; flex-direction: column; gap: 0.5rem;
  }
  .summary-item { display: flex; justify-content: space-between; font-size: 0.85rem; }
  .summary-item .label { color: var(--text-muted); }
  .summary-item .val { font-weight: 700; color: white; font-family: 'JetBrains Mono', monospace; }
  
  .summary-total { 
    margin-top: 0.5rem; padding-top: 0.75rem; border-top: 1px dashed rgba(255,255,255,0.1); 
    display: flex; justify-content: space-between; align-items: flex-end;
    position: relative; overflow: hidden;
  }
  .summary-total .label { font-weight: 800; color: white; text-transform: uppercase; font-size: 0.75rem; }
  .summary-total .val { font-size: 1.5rem; font-weight: 900; }

  /* Liquid Shine Effect (High Intensity) */
  .shine-text {
    background: linear-gradient(
      90deg, 
      #e00800 0%, 
      #e00800 35%, 
      #ffffff 50%, 
      #e00800 65%, 
      #e00800 100%
    );
    background-size: 200% auto;
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    animation: liquid-shine 2s linear infinite;
    font-weight: 900;
  }

  @keyframes liquid-shine {
    to { background-position: 200% center; }
  }

  .breakdown-list { display: flex; flex-direction: column; gap: 0.75rem; }
  .breakdown-row {
    background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.05);
    border-radius: 12px; padding: 1rem; display: flex; align-items: center; gap: 1rem;
    transition: all 0.2s;
  }
  .breakdown-row:hover { background: rgba(255,255,255,0.05); border-color: rgba(255,255,255,0.1); }
  .item-icon { width: 40px; height: 40px; border-radius: 10px; display: flex; align-items: center; justify-content: center; }
  .item-icon.voice { background: rgba(59, 130, 246, 0.1); color: #3b82f6; }
  .item-icon.data { background: rgba(168, 85, 247, 0.1); color: #a855f7; }
  .item-icon.sms { background: rgba(245, 158, 11, 0.1); color: #f59e0b; }
  
  .item-details { flex: 1; }
  .item-name { font-weight: 700; color: white; font-size: 0.95rem; margin-bottom: 2px; display: flex; align-items: center; gap: 8px; }
  .roaming-tag { font-size: 0.6rem; background: #f59e0b; color: black; padding: 1px 4px; border-radius: 4px; font-weight: 900; text-transform: uppercase; }
  .item-quota { font-size: 0.75rem; color: var(--text-muted); font-family: 'JetBrains Mono', monospace; }
  .item-cost { font-weight: 800; color: white; font-size: 1rem; font-family: 'JetBrains Mono', monospace; }

  .drawer-loader { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 1rem; color: var(--text-muted); }
  .spinner { width: 40px; height: 40px; border: 4px solid rgba(255,255,255,0.05); border-top-color: var(--red); border-radius: 50%; animation: spin 1s linear infinite; }
  @keyframes spin { to { transform: rotate(360deg); } }
  
  .accent-orange { color: #f59e0b !important; }
  .text-gradient { background: linear-gradient(135deg, var(--red), #ff4d4d); -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text; }

  .badge { padding: 4px 10px; border-radius: 6px; font-size: 0.7rem; font-weight: 900; text-transform: uppercase; border: 1px solid transparent; }
  .status-paid { background: rgba(34, 197, 94, 0.1); color: #22c55e; border-color: rgba(34, 197, 94, 0.2); }
  .status-issued { background: rgba(59, 130, 246, 0.1); color: #3b82f6; border-color: rgba(59, 130, 246, 0.2); }
</style>
