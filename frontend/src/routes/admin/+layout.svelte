<script>
  import '../../lib/components/Toast.svelte';
  import { toastState, hideToast } from '$lib/toast.svelte.js';
  
  /** @type {{ children: import('svelte').Snippet, data: import('./$types').PageData }} */
  let { children, data } = $props();
  
  // Get environment from server load function
  let envDisplay = $derived(data?.environment || 'development');
  let isDev = $derived(envDisplay !== 'production');
</script>

<div class="admin-layout">
  <!-- Environment Badge -->
  <div class="env-badge" class:production={!isDev}>
    {isDev ? '🛠️ DEVELOPMENT' : '🔴 PRODUCTION'}
  </div>
  
  {@render children()}
</div>

<style>
  .admin-layout {
    position: relative;
  }
  
  .env-badge {
    position: fixed;
    top: 72px;
    right: 16px;
    z-index: 1000;
    padding: 6px 12px;
    border-radius: 4px;
    font-size: 11px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    background: #22c55e;
    color: white;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
  }
  
  .env-badge.production {
    background: #dc2626;
  }
</style>