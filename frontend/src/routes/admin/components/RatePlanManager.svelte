<script>
  import { onMount } from 'svelte';
  import { fade, fly } from 'svelte/transition';
  import { showToast } from '$lib/toast.svelte.js';
  import Modal from '$lib/components/Modal.svelte';

  let rateplans = $state([]);
  let allPackages = $state([]);
  let loading = $state(true);
  let showModal = $state(false);
  let isEditing = $state(false);
  let currentPlan = $state({
    name: '',
    ror_voice: 0.10,
    ror_data: 0.25,
    ror_sms: 0.05,
    price: 0,
    type: 'POSTPAID',
    servicePackageIds: []
  });

  function formatUsage(value, type) {
    if (!value) return '0';
    const t = String(type || '').toLowerCase();
    if (t === 'voice') {
      if (value >= 60) return (value / 60).toFixed(1) + ' min';
      return value + ' sec';
    }
    if (t === 'data') {
      if (value >= 1073741824) return (value / 1073741824).toFixed(2) + ' GB';
      if (value >= 1048576) return (value / 1048576).toFixed(1) + ' MB';
      return (value / 1024).toFixed(1) + ' KB';
    }
    return value;
  }

  async function fetchData() {
    loading = true;
    try {
      const [planRes, pkgRes] = await Promise.all([
        fetch('/api/admin/rateplans', { credentials: 'include' }),
        fetch('/api/admin/service-packages', { credentials: 'include' })
      ]);
      if (planRes.ok) rateplans = await planRes.json();
      if (pkgRes.ok) allPackages = await pkgRes.json();
    } catch (e) {
      showToast('Failed to fetch data', 'error');
    } finally {
      loading = false;
    }
  }

  function openCreateModal() {
    isEditing = false;
    currentPlan = {
      name: '',
      ror_voice: 0.10,
      ror_data: 0.25,
      ror_sms: 0.05,
      price: 0,
      type: 'POSTPAID',
      servicePackageIds: []
    };
    showModal = true;
  }

  async function openEditModal(plan) {
    isEditing = true;
    // Fetch details to get current linked packages
    try {
        const res = await fetch(`/api/admin/rateplans/${plan.id}`, { credentials: 'include' });
        if (res.ok) {
            const details = await res.json();
            currentPlan = { 
                ...plan, 
                servicePackageIds: details.servicePackageIds || [] 
            };
        } else {
            currentPlan = { ...plan, servicePackageIds: [] };
        }
    } catch (e) {
        currentPlan = { ...plan, servicePackageIds: [] };
    }
    showModal = true;
  }

  function togglePackage(id) {
    if (currentPlan.servicePackageIds.includes(id)) {
      currentPlan.servicePackageIds = currentPlan.servicePackageIds.filter(pid => pid !== id);
    } else {
      currentPlan.servicePackageIds = [...currentPlan.servicePackageIds, id];
    }
  }

  async function savePlan() {
    const url = isEditing ? `/api/admin/rateplans/${currentPlan.id}` : '/api/admin/rateplans';
    const method = isEditing ? 'PUT' : 'POST';
    try {
      const res = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify(currentPlan)
      });
      if (res.ok) {
        showToast(`Rate plan ${isEditing ? 'updated' : 'created'} successfully`);
        showModal = false;
        fetchData();
      } else {
        const data = await res.json();
        showToast(data.message || 'Action failed', 'error');
      }
    } catch (e) {
      showToast('Connection error', 'error');
    }
  }

  async function deletePlan(id) {
    if (!confirm('Are you sure you want to delete this rate plan?')) return;
    try {
      const res = await fetch(`/api/admin/rateplans/${id}`, { 
        method: 'DELETE',
        credentials: 'include'
      });
      if (res.ok) {
        showToast('Rate plan deleted successfully');
        fetchData();
      } else {
        const data = await res.json();
        showToast(data.message || 'Delete failed', 'error');
      }
    } catch (e) {
      showToast('Connection error', 'error');
    }
  }

  onMount(fetchData);
</script>

<div class="manager-content">
  <div class="page-header">
    <div>
      <h2 class="sub-title">Rate <span class="text-gradient">Plans</span></h2>
      <p class="page-subtitle">Define base pricing and default bundled services</p>
    </div>
    <button class="btn btn-primary" onclick={openCreateModal}>
      <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14"/><path d="M12 5v14"/></svg>
      New Rate Plan
    </button>
  </div>

  {#if loading}
    <div class="loading-state">
      <div class="spinner"></div>
      <span>Syncing catalog...</span>
    </div>
  {:else}
    <div class="table-wrapper animate-fade">
      <table class="pkg-table">
        <thead>
          <tr>
            <th>Rate Plan</th>
            <th>Voice Overage</th>
            <th>Data Overage</th>
            <th>SMS Overage</th>
            <th>Base Monthly</th>
            <th style="text-align: right;">System Actions</th>
          </tr>
        </thead>
        <tbody>
          {#each rateplans as plan}
            <tr class="pkg-row">
              <td>
                <div class="name-cell">
                  <div class="accent-bar accent-free"></div>
                  <div class="name-info">
                    <div class="pkg-name">{plan.name}</div>
                    <div class="plan-type-badge" class:prepaid={plan.type === 'PREPAID'}>{plan.type}</div>
                  </div>
                </div>
              </td>
              <td>
                <div class="data-chip voice-chip">
                  <span class="chip-val">{plan.ror_voice}</span>
                  <span class="chip-unit">EGP/MIN</span>
                </div>
              </td>
              <td>
                <div class="data-chip data-chip-variant">
                  <span class="chip-val">{plan.ror_data}</span>
                  <span class="chip-unit">EGP/MB</span>
                </div>
              </td>
              <td>
                <div class="data-chip sms-chip">
                  <span class="chip-val">{plan.ror_sms}</span>
                  <span class="chip-unit">EGP/MSG</span>
                </div>
              </td>
              <td>
                <div class="price-pill">
                  <span class="currency">EGP</span>{plan.price}
                </div>
              </td>
              <td style="text-align: right;">
                <div class="actions">
                  <button class="icon-btn edit" onclick={() => openEditModal(plan)} title="Modify Configuration">
                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
                  </button>
                  <button class="icon-btn delete" onclick={() => deletePlan(plan.id)} title="Decommission Plan">
                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/><line x1="10" y1="11" x2="10" y2="17"/><line x1="14" y1="11" x2="14" y2="17"/></svg>
                  </button>
                </div>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</div>

<Modal 
  bind:show={showModal} 
  title={isEditing ? 'Edit Rate Plan' : 'Create Rate Plan'} 
  subtitle={isEditing ? `Modifying ${currentPlan.name}` : 'Configure base rates and inclusions'}
>
  <div class="form-grid">
    <div class="form-group full">
      <label>Plan Name</label>
      <input type="text" class="input" bind:value={currentPlan.name} placeholder="e.g. Gold Unlimited" />
    </div>

    <div class="form-group">
      <label>Voice Overage Rate (EGP/min)</label>
      <input type="number" step="0.01" class="input" bind:value={currentPlan.ror_voice} />
    </div>

    <div class="form-group">
      <label>Data Overage Rate (EGP/MB)</label>
      <input type="number" step="0.01" class="input" bind:value={currentPlan.ror_data} />
    </div>

    <div class="form-group">
      <label>SMS Overage Rate (EGP/msg)</label>
      <input type="number" step="0.01" class="input" bind:value={currentPlan.ror_sms} />
    </div>

    <div class="form-group">
      <label>Monthly Subscription Price (EGP)</label>
      <input type="number" class="input" bind:value={currentPlan.price} />
    </div>

    <div class="form-group full">
      <label>Billing Model</label>
      <div class="type-selector">
        <button class="type-btn" class:active={currentPlan.type === 'POSTPAID'} onclick={() => currentPlan.type = 'POSTPAID'}>POSTPAID</button>
        <button class="type-btn" class:active={currentPlan.type === 'PREPAID'} onclick={() => currentPlan.type = 'PREPAID'}>PREPAID</button>
      </div>
    </div>

    <div class="form-group full">
      <label>Included Service Packages</label>
      <div class="packages-selection">
        {#each allPackages as pkg}
          <button 
            class="pkg-toggle-btn" 
            class:selected={currentPlan.servicePackageIds.includes(pkg.id)}
            onclick={() => togglePackage(pkg.id)}
          >
            <span class="pkg-name">{pkg.name}</span>
            <span class="pkg-meta">{formatUsage(pkg.amount, pkg.type)}</span>
            {#if currentPlan.servicePackageIds.includes(pkg.id)}
              <div class="check-overlay">✓</div>
            {/if}
          </button>
        {/each}
        {#if allPackages.length === 0}
          <div class="empty-packages">No service packages found. Create some first!</div>
        {/if}
      </div>
    </div>
  </div>

  <div class="modal-actions">
    <button class="btn btn-secondary" onclick={() => showModal = false}>Cancel</button>
    <button class="btn btn-primary" onclick={savePlan}>
      {isEditing ? 'Update Plan' : 'Create Plan'}
    </button>
  </div>
</Modal>

<style>
  .page-header { display: flex; justify-content: space-between; align-items: flex-end; margin-bottom: 1rem; }
  .page-subtitle { color: var(--text-muted); font-size: 1rem; margin-top: 0.25rem; }
  .grid-table { background: var(--bg-card); border: 1px solid var(--border); border-radius: var(--radius-lg); overflow: hidden; max-width: 1600px; width: 100%; margin: 0 auto; }
  .table-header { display: grid; grid-template-columns: 2fr 1fr 1fr 1fr 1fr 120px; background: rgba(255, 255, 255, 0.03); padding: 0.5rem 1rem; border-bottom: 1px solid var(--border); font-weight: 700; color: var(--text-muted); text-transform: uppercase; font-size: 0.75rem; letter-spacing: 0.05em; }
  .table-row { display: grid; grid-template-columns: 2fr 1fr 1fr 1fr 1fr 120px; padding: 0.5rem 1rem; border-bottom: 1px solid rgba(255, 255, 255, 0.03); align-items: center; transition: background 0.2s; }
  .table-row:hover { background: rgba(255, 255, 255, 0.02); }
  .table-row:last-child { border-bottom: none; }
  
  .name-col { display: flex; flex-direction: column; gap: 0.25rem; }
  .name-col strong { color: white; font-size: 1.05rem; letter-spacing: -0.01em; }
  .plan-type-badge { font-size: 0.65rem; font-weight: 900; color: #3b82f6; background: rgba(59, 130, 246, 0.1); border: 1px solid rgba(59, 130, 246, 0.2); padding: 1px 6px; border-radius: 4px; width: fit-content; letter-spacing: 0.1em; }
  .plan-type-badge.prepaid { color: #f59e0b; background: rgba(245, 158, 11, 0.1); border-color: rgba(245, 158, 11, 0.2); }
  
  .unit-box .val { font-family: 'JetBrains Mono', monospace; font-size: 1.25rem; font-weight: 900; color: white; line-height: 1; margin-bottom: 2px; }
  
  .unit-box .unit { font-size: 0.65rem; color: var(--text-muted); font-weight: 700; text-transform: uppercase; opacity: 0.8; }
  
  .box-voice { background: rgba(59, 130, 246, 0.15); border-color: rgba(59, 130, 246, 0.3); }
  .box-voice .val { color: #60A5FA; text-shadow: 0 0 15px rgba(96, 165, 250, 0.3); }
  
  /* Elite Precision Table System */
  .pkg-table { width: 100%; border-collapse: separate; border-spacing: 0 8px; margin-top: 1rem; }
  .pkg-table th { padding: 12px 20px; font-size: 0.7rem; text-transform: uppercase; letter-spacing: 0.1em; color: var(--text-muted); font-weight: 800; border: none; text-align: left; }
  
  .pkg-row { 
    background: rgba(255, 255, 255, 0.02); 
    border: 1px solid rgba(255, 255, 255, 0.05);
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  }
  
  .pkg-row:hover {
    background: rgba(255, 255, 255, 0.05);
    border-color: rgba(255, 255, 255, 0.15);
    transform: scale(1.002) translateX(4px);
    box-shadow: -10px 0 30px rgba(0, 0, 0, 0.5);
  }
  
  .pkg-row td { padding: 12px 20px; border: none; vertical-align: middle; }
  .pkg-row td:first-child { border-top-left-radius: 12px; border-bottom-left-radius: 12px; }
  .pkg-row td:last-child { border-top-right-radius: 12px; border-bottom-right-radius: 12px; }

  /* Service Type Accent Bars */
  .accent-bar { width: 4px; height: 32px; border-radius: 2px; margin-right: 12px; }
  .accent-voice { background: #3b82f6; box-shadow: 0 0 10px rgba(59, 130, 246, 0.5); }
  .accent-data { background: #10b981; box-shadow: 0 0 10px rgba(16, 185, 129, 0.5); }
  .accent-sms { background: #8b5cf6; box-shadow: 0 0 10px rgba(139, 92, 246, 0.5); }
  .accent-free { background: #f59e0b; box-shadow: 0 0 10px rgba(245, 158, 11, 0.5); }

  .name-cell { display: flex; align-items: center; }
  .pkg-name { font-weight: 800; font-size: 1rem; color: white; margin-bottom: 2px; }
  .pkg-desc { font-size: 0.75rem; color: var(--text-muted); font-weight: 500; }

  /* Precision Data Chips */
  .data-chip {
    display: inline-flex;
    align-items: center;
    background: rgba(255, 255, 255, 0.03);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 8px;
    overflow: hidden;
    height: 36px;
  }
  .chip-val { 
    padding: 0 12px; 
    font-family: 'JetBrains Mono', monospace; 
    font-weight: 900; 
    font-size: 0.95rem; 
    height: 100%;
    display: flex;
    align-items: center;
  }
  .chip-unit { 
    padding: 0 10px; 
    background: rgba(255, 255, 255, 0.05); 
    font-size: 0.6rem; 
    font-weight: 800; 
    color: var(--text-muted); 
    text-transform: uppercase;
    height: 100%;
    display: flex;
    align-items: center;
    border-left: 1px solid rgba(255, 255, 255, 0.05);
  }

  .voice-chip { color: #60a5fa; border-color: rgba(96, 165, 250, 0.2); }
  .data-chip-variant { color: #34d399; border-color: rgba(52, 211, 153, 0.2); }
  .sms-chip { color: #a78bfa; border-color: rgba(167, 139, 250, 0.2); }
  .free-chip { color: #f59e0b; border-color: rgba(245, 158, 11, 0.2); }

  .price-pill {
    background: rgba(255, 255, 255, 0.06);
    padding: 4px 12px;
    border-radius: 6px;
    font-family: 'JetBrains Mono', monospace;
    font-weight: 800;
    color: white;
    font-size: 0.9rem;
    border: 1px solid rgba(255, 255, 255, 0.1);
  }
  .currency { font-size: 0.65rem; color: var(--text-muted); margin-right: 4px; }
  
  .box-data { background: rgba(16, 185, 129, 0.15); border-color: rgba(16, 185, 129, 0.3); }
  .box-data .val { color: #34D399; text-shadow: 0 0 15px rgba(52, 211, 153, 0.3); }
  
  .box-sms { background: rgba(139, 92, 246, 0.15); border-color: rgba(139, 92, 246, 0.3); }
  .box-sms .val { color: #A78BFA; text-shadow: 0 0 15px rgba(167, 139, 250, 0.3); }
  
  
  .actions { display: flex; gap: 0.75rem; justify-content: flex-end; }
  .icon-btn { background: rgba(255, 255, 255, 0.05); border: 1px solid rgba(255, 255, 255, 0.1); color: var(--text-muted); padding: 8px; border-radius: 8px; cursor: pointer; transition: all 0.2s; display: flex; align-items: center; justify-content: center; }
  .icon-btn:hover { color: white; background: rgba(255, 255, 255, 0.1); transform: scale(1.1); }
  .icon-btn.edit:hover { border-color: #3B82F6; color: #3B82F6; }
  .icon-btn.delete:hover { border-color: var(--red); color: var(--red); }
  
  .form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1.5rem; margin-top: 1rem; }
  .form-group.full { grid-column: span 2; }
  .form-group label { display: block; margin-bottom: 0.5rem; font-weight: 600; font-size: 0.9rem; color: var(--text-muted); }
  .input { width: 100%; background: rgba(255, 255, 255, 0.03); border: 1px solid var(--border); border-radius: 10px; padding: 0.75rem 1rem; color: white; transition: all 0.3s; }
  .input:focus { outline: none; border-color: var(--red); background: rgba(224, 8, 0, 0.05); }
  
  .packages-selection { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 0.75rem; max-height: 250px; overflow-y: auto; padding: 10px; background: rgba(0,0,0,0.2); border-radius: 12px; border: 1px solid var(--border); }
  .pkg-toggle-btn { position: relative; display: flex; flex-direction: column; align-items: flex-start; text-align: left; padding: 1rem; background: rgba(255,255,255,0.03); border: 1px solid var(--border); border-radius: 10px; cursor: pointer; transition: all 0.2s; }
  .pkg-toggle-btn:hover { background: rgba(255,255,255,0.06); border-color: rgba(255,255,255,0.2); }
  .pkg-toggle-btn.selected { border-color: var(--red); background: rgba(224, 8, 0, 0.08); }
  .pkg-name { font-weight: 700; color: white; font-size: 0.9rem; margin-bottom: 0.25rem; }
  .pkg-meta { font-size: 0.75rem; color: var(--text-muted); }
  .check-overlay { position: absolute; top: 0.5rem; right: 0.5rem; width: 20px; height: 20px; background: var(--red); color: white; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 12px; font-weight: 900; }
  
  .type-selector { display: flex; gap: 10px; background: rgba(0,0,0,0.2); padding: 5px; border-radius: 12px; border: 1px solid var(--border); }
  .type-btn { flex: 1; padding: 10px; border: none; background: none; color: var(--text-muted); font-weight: 800; cursor: pointer; border-radius: 8px; transition: all 0.2s; }
  .type-btn.active { background: var(--red); color: white; box-shadow: 0 4px 12px rgba(224, 8, 0, 0.3); }
  
  .modal-actions { display: flex; gap: 1rem; margin-top: 2.5rem; }
  .modal-actions button { flex: 1; }
  .loading-state { display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 5rem; gap: 1rem; color: var(--text-muted); }
  .spinner { width: 40px; height: 40px; border: 3px solid rgba(224, 8, 0, 0.1); border-top-color: var(--red); border-radius: 50%; animation: spin 1s linear infinite; }
  @keyframes spin { to { transform: rotate(360deg); } }
  .empty-packages { grid-column: 1 / -1; padding: 2rem; text-align: center; color: var(--text-muted); font-style: italic; }
</style>
