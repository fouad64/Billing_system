<script>
  import { onMount } from 'svelte';
  import { fade, fly } from 'svelte/transition';
  import { showToast } from '$lib/toast.svelte.js';
  import Modal from '$lib/components/Modal.svelte';

  let packages = $state([]);
  let loading = $state(true);
  let showModal = $state(false);
  let isEditing = $state(false);
  let currentPkg = $state({
    name: '',
    type: 'voice',
    amount: 0,
    priority: 10,
    price: 0,
    description: '',
    is_roaming: false
  });
  let displayAmount = $state(0);
  let displayUnit = $state('');

  function formatUsage(value, type) {
    if (!value && value !== 0) return '0';
    const t = String(type || '').toLowerCase();
    
    // Smart formatting for Voice (Seconds to Minutes)
    if (t === 'voice') {
      if (value >= 60) return (value / 60).toFixed(1) + ' min';
      return value + ' sec';
    }
    
    // Smart formatting for Data/Free Units (Bytes to GB/MB)
    if (t === 'data' || t === 'free_units' || value > 1000000) {
      if (value >= 1073741824) return (value / 1073741824).toFixed(2) + ' GB';
      if (value >= 1048576) return (value / 1048576).toFixed(1) + ' MB';
      if (value >= 1024) return (value / 1024).toFixed(1) + ' KB';
      return value + ' B';
    }

    if (t === 'sms') return value + ' SMS';
    
    return value;
  }

  async function fetchPackages() {
    loading = true;
    try {
      const res = await fetch('/api/admin/service-packages', { credentials: 'include' });
      if (res.ok) {
        packages = await res.json();
      }
    } catch (e) {
      showToast('Failed to fetch packages', 'error');
    } finally {
      loading = false;
    }
  }

  function openCreateModal() {
    isEditing = false;
    currentPkg = {
      name: '',
      type: 'voice',
      amount: 0,
      priority: 10,
      price: 0,
      description: '',
      is_roaming: false
    };
    displayAmount = 0;
    displayUnit = 'min';
    showModal = true;
  }

  function openEditModal(pkg) {
    isEditing = true;
    currentPkg = { ...pkg };
    
    // Set display values
    if (pkg.type === 'voice') {
      if (pkg.amount % 60 === 0) {
        displayAmount = pkg.amount / 60;
        displayUnit = 'min';
      } else {
        displayAmount = pkg.amount;
        displayUnit = 'sec';
      }
    } else if (pkg.type === 'data') {
      if (pkg.amount % 1073741824 === 0) {
        displayAmount = pkg.amount / 1073741824;
        displayUnit = 'GB';
      } else if (pkg.amount % 1048576 === 0) {
        displayAmount = pkg.amount / 1048576;
        displayUnit = 'MB';
      } else {
        displayAmount = pkg.amount;
        displayUnit = 'B';
      }
    } else {
      displayAmount = pkg.amount;
      displayUnit = 'count';
    }
    showModal = true;
  }

  async function savePackage() {
    // Convert display to raw
    if (currentPkg.type === 'voice') {
      currentPkg.amount = displayUnit === 'min' ? displayAmount * 60 : displayAmount;
    } else if (currentPkg.type === 'data') {
      if (displayUnit === 'GB') currentPkg.amount = Math.round(displayAmount * 1073741824);
      else if (displayUnit === 'MB') currentPkg.amount = Math.round(displayAmount * 1048576);
      else currentPkg.amount = displayAmount;
    } else {
      currentPkg.amount = displayAmount;
    }

    const url = isEditing ? `/api/admin/service-packages/${currentPkg.id}` : '/api/admin/service-packages';
    const method = isEditing ? 'PUT' : 'POST';
    try {
      const res = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify(currentPkg)
      });
      if (res.ok) {
        showToast(`Package ${isEditing ? 'updated' : 'created'} successfully`);
        showModal = false;
        fetchPackages();
      } else {
        const data = await res.json();
        showToast(data.message || 'Action failed', 'error');
      }
    } catch (e) {
      showToast('Connection error', 'error');
    }
  }

  async function deletePackage(id) {
    if (!confirm('Are you sure you want to delete this package?')) return;
    try {
      const res = await fetch(`/api/admin/service-packages/${id}`, { 
        method: 'DELETE',
        credentials: 'include'
      });
      if (res.ok) {
        showToast('Package deleted successfully');
        fetchPackages();
      } else {
        const data = await res.json();
        showToast(data.message || 'Delete failed', 'error');
      }
    } catch (e) {
      showToast('Connection error', 'error');
    }
  }

  onMount(fetchPackages);
</script>

<div class="manager-content">
  <div class="page-header">
    <div>
      <h2 class="sub-title">Service <span class="text-gradient">Packages</span></h2>
      <p class="page-subtitle">Configure bundle quotas and priority</p>
    </div>
    <button class="btn btn-primary" onclick={openCreateModal}>
      <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14"/><path d="M12 5v14"/></svg>
      New Package
    </button>
  </div>

  {#if loading}
    <div class="loading-state">
      <div class="spinner"></div>
      <p>Synchronizing Portfolio...</p>
    </div>
  {:else}
    <div class="table-wrapper animate-fade">
      <table class="pkg-table">
        <thead>
          <tr>
            <th>Service Package</th>
            <th>Type</th>
            <th>Quota Amount</th>
            <th>Base Price</th>
            <th>Priority</th>
            <th>Roaming</th>
            <th style="text-align: right;">System Actions</th>
          </tr>
        </thead>
        <tbody>
          {#each packages as pkg}
            <tr class="pkg-row">
              <td>
                <div class="name-cell">
                  <div class="accent-bar accent-{pkg.type.toLowerCase() === 'data' ? 'data' : pkg.type.toLowerCase() === 'voice' ? 'voice' : pkg.type.toLowerCase() === 'sms' ? 'sms' : 'free'}"></div>
                  <div class="name-info">
                    <div class="pkg-name">{pkg.name}</div>
                    <div class="pkg-desc">{pkg.description || 'Enterprise-grade service bundle'}</div>
                  </div>
                </div>
              </td>
              <td>
                <span class="badge badge-{pkg.type.toLowerCase()}">{pkg.type}</span>
              </td>
              <td>
                <div class="data-chip {pkg.type.toLowerCase() === 'data' ? 'data-chip-variant' : pkg.type.toLowerCase() === 'voice' ? 'voice-chip' : pkg.type.toLowerCase() === 'sms' ? 'sms-chip' : 'free-chip'}">
                  <span class="chip-val">{formatUsage(pkg.amount, pkg.type).split(' ')[0]}</span>
                  <span class="chip-unit">{formatUsage(pkg.amount, pkg.type).split(' ')[1] || ''}</span>
                </div>
              </td>
              <td>
                <div class="price-pill">
                  <span class="currency">EGP</span>{pkg.price}
                </div>
              </td>
              <td>
                <div class="id-badge">{pkg.priority}</div>
              </td>
              <td>
                <span class="roaming-status" class:is-roaming={pkg.is_roaming}>
                  {pkg.is_roaming ? 'Active' : 'No'}
                </span>
              </td>
              <td style="text-align: right;">
                <div class="actions">
                  <button class="icon-btn edit" onclick={() => openEditModal(pkg)} title="Modify Configuration">
                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
                  </button>
                  <button class="icon-btn delete" onclick={() => deletePackage(pkg.id)} title="Decommission Package">
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
  title={isEditing ? 'Edit Package' : 'Create Package'} 
  subtitle={isEditing ? `Modifying ${currentPkg.name}` : 'Define new quota bundle'}
>
  <div class="form-grid">
    <div class="form-group full">
      <label>Package Name</label>
      <input type="text" class="input" bind:value={currentPkg.name} placeholder="e.g. Summer Data Boost" />
    </div>

    <div class="form-group">
      <label>Service Type</label>
      <select class="input" bind:value={currentPkg.type}>
        <option value="voice">Voice</option>
        <option value="data">Data</option>
        <option value="sms">SMS</option>
      </select>
    </div>

    <div class="form-group">
      <label>Quota Amount</label>
      <div style="display: flex; gap: 0.5rem;">
        <input type="number" class="input" style="flex: 1" bind:value={displayAmount} />
        <select class="input" style="width: 100px;" bind:value={displayUnit}>
          {#if currentPkg.type === 'voice'}
            <option value="min">Min</option>
            <option value="sec">Sec</option>
          {:else if currentPkg.type === 'data'}
            <option value="GB">GB</option>
            <option value="MB">MB</option>
            <option value="B">Bytes</option>
          {:else}
            <option value="count">Count</option>
          {/if}
        </select>
      </div>
    </div>

    <div class="form-group">
      <label>Price (EGP)</label>
      <input type="number" class="input" bind:value={currentPkg.price} />
    </div>

    <div class="form-group">
      <label>Priority (Lower = First)</label>
      <input type="number" class="input" bind:value={currentPkg.priority} />
    </div>

    <div class="form-group full">
      <label>Description</label>
      <textarea class="input" rows="3" bind:value={currentPkg.description} placeholder="Describe what's in the package..."></textarea>
    </div>

    <div class="form-group full checkbox-group">
      <label class="checkbox-container">
        <input type="checkbox" bind:checked={currentPkg.is_roaming} />
        <span class="checkmark"></span>
        Enable for Roaming Usage
      </label>
    </div>
  </div>

  <div class="modal-actions">
    <button class="btn btn-secondary" onclick={() => showModal = false}>Cancel</button>
    <button class="btn btn-primary" onclick={savePackage}>
      {isEditing ? 'Update Package' : 'Create Package'}
    </button>
  </div>
</Modal>

<style>
  .text-gradient { background: linear-gradient(135deg, var(--red), var(--red-light)); -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text; }
  .page-header { display: flex; justify-content: space-between; align-items: flex-end; margin-bottom: 1rem; }
  .page-subtitle { color: var(--text-muted); font-size: 1rem; margin-top: 0.25rem; }
  .grid-table { background: var(--bg-card); border: 1px solid var(--border); border-radius: var(--radius-lg); overflow: hidden; max-width: 1600px; width: 100%; margin: 0 auto; }
  .table-header { display: grid; grid-template-columns: 2fr 1fr 1fr 1fr 0.8fr 0.8fr 120px; background: rgba(255, 255, 255, 0.03); padding: 0.5rem 1rem; border-bottom: 1px solid var(--border); font-weight: 700; color: var(--text-muted); text-transform: uppercase; font-size: 0.75rem; letter-spacing: 0.05em; }
  .table-row { display: grid; grid-template-columns: 2fr 1fr 1fr 1fr 0.8fr 0.8fr 120px; padding: 0.5rem 1rem; border-bottom: 1px solid rgba(255, 255, 255, 0.03); align-items: center; transition: background 0.2s; }
  .table-row:hover { background: rgba(255, 255, 255, 0.02); }
  
  .badge { padding: 4px 10px; border-radius: 6px; font-size: 0.75rem; font-weight: 700; text-transform: uppercase; border: 1px solid transparent; }  /* Elite Refinement Styles */
  .pkg-table { width: 100%; border-collapse: separate; border-spacing: 0 8px; margin-top: 1rem; }
  .pkg-table th { padding: 12px 20px; font-size: 0.7rem; text-transform: uppercase; letter-spacing: 0.1em; color: var(--text-muted); font-weight: 800; border: none; }
  
  .pkg-row { 
    background: rgba(255, 255, 255, 0.02); 
    border: 1px solid rgba(255, 255, 255, 0.05);
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    position: relative;
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
  .actions { display: flex; gap: 0.75rem; justify-content: flex-end; }
  .icon-btn { background: rgba(255, 255, 255, 0.05); border: 1px solid rgba(255, 255, 255, 0.1); color: var(--text-muted); padding: 8px; border-radius: 8px; cursor: pointer; transition: all 0.2s; display: flex; align-items: center; justify-content: center; }
  .icon-btn:hover { color: white; background: rgba(255, 255, 255, 0.1); transform: scale(1.1); }
  .icon-btn.edit:hover { border-color: #3B82F6; color: #3B82F6; }
  .icon-btn.delete:hover { border-color: var(--red); color: var(--red); }
  
  .badge-voice { background: rgba(59, 130, 246, 0.1); color: #60a5fa; border-color: rgba(59, 130, 246, 0.2); }
  .badge-data { background: rgba(16, 185, 129, 0.1); color: #34d399; border-color: rgba(16, 185, 129, 0.2); }
  .badge-sms { background: rgba(139, 92, 246, 0.1); color: #a78bfa; border-color: rgba(139, 92, 246, 0.2); }
  .badge-free_units { background: rgba(245, 158, 11, 0.1); color: #f59e0b; border-color: rgba(245, 158, 11, 0.2); }

  .form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1.5rem; margin-top: 1rem; }
  .form-group.full { grid-column: span 2; }
  .form-group label { display: block; margin-bottom: 0.5rem; font-weight: 600; font-size: 0.9rem; color: var(--text-muted); }
  .input { width: 100%; background: rgba(255, 255, 255, 0.03); border: 1px solid var(--border); border-radius: 10px; padding: 0.75rem 1rem; color: white; transition: all 0.3s; }
  .input:focus { outline: none; border-color: var(--red); background: rgba(224, 8, 0, 0.05); }
  .checkbox-group { display: flex; align-items: center; margin-top: 0.5rem; }
  .checkbox-container { display: flex; align-items: center; gap: 10px; cursor: pointer; user-select: none; font-weight: 600; color: white; }
  .checkbox-container input { display: none; }
  .checkmark { width: 20px; height: 20px; border: 2px solid var(--border); border-radius: 6px; display: flex; align-items: center; justify-content: center; transition: all 0.2s; }
  .checkbox-container input:checked + .checkmark { background: var(--red); border-color: var(--red); }
  .checkbox-container input:checked + .checkmark::after { content: '✓'; color: white; font-size: 14px; font-weight: 900; }
  .modal-actions { display: flex; gap: 1rem; margin-top: 2.5rem; }
  .modal-actions button { flex: 1; }
  .loading-state { display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 5rem; gap: 1rem; color: var(--text-muted); }
  .spinner { width: 40px; height: 40px; border: 3px solid rgba(224, 8, 0, 0.1); border-top-color: var(--red); border-radius: 50%; animation: spin 1s linear infinite; }
  @keyframes spin { to { transform: rotate(360deg); } }
</style>
