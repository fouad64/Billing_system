<script>
  let plans = $state([]);
  let currentPlan = $state(0);
  let servicePkgs = $state([]);
  let loading = $state(true);

  async function loadData() {
    try {
      const [plansRes, pkgsRes] = await Promise.all([
        fetch('/api/public/rateplans'),
        fetch('/api/public/service-packages')
      ]);
      if (plansRes.ok) plans = await plansRes.json();
      if (pkgsRes.ok) servicePkgs = await pkgsRes.json();
    } catch (e) {
      plans = [];
      servicePkgs = [];
    }
    loading = false;
  }

  $effect(() => {
    loadData();
    const interval = setInterval(() => {
      if (plans.length > 0) {
        currentPlan = (currentPlan + 1) % plans.length;
      }
    }, 5000);
    return () => clearInterval(interval);
  });
</script>

<svelte:head>
  <title>Packages — FMRZ</title>
</svelte:head>

<div class="container">
  <div class="page-header">
    <div>
      <h1>Rate Plans & <span class="text-gradient">Packages</span></h1>
      <p class="page-subtitle">Choose the perfect plan for your communication needs</p>
    </div>
  </div>

  {#if loading}
    <div class="loading">Loading...</div>
  {:else}
    <!-- ─── RATE PLANS ─── -->
    <h2 class="section-title">Standard Rate Plans</h2>

    <div class="plan-grid">
      {#each plans as plan, i}
        <div class="plan-card card animate-fade" style="animation-delay: {i * 0.1}s">
          {#if i === 1}
            <div class="plan-badge popular">⭐ Most Popular</div>
          {/if}

          <div class="plan-header">
            <h3>{plan.name}</h3>
            <div class="plan-price">
              <span class="currency">EGP</span>
              <span class="amount">{plan.price}</span>
              <span class="period">/mo</span>
            </div>
          </div>

          <div class="plan-details">
            <div class="detail-row">
              <span class="detail-label">📞 Voice Rate</span>
              <span class="detail-value">{plan.ror_voice} <small>EGP/min</small></span>
            </div>
            <div class="detail-row">
              <span class="detail-label">🌐 Data Rate</span>
              <span class="detail-value">{plan.ror_data} <small>EGP/MB</small></span>
            </div>
            <div class="detail-row">
              <span class="detail-label">💬 SMS Rate</span>
              <span class="detail-value">{plan.ror_sms} <small>EGP/msg</small></span>
            </div>
            <div class="detail-row">
              <span class="detail-label">💳 Monthly Fee</span>
              <span class="detail-value">EGP {plan.price}</span>
            </div>
          </div>

          <button onclick={() => window.location.href = '/register?plan=' + plan.id} class="btn btn-primary" style="width: 100%;">
            Choose {plan.name}
          </button>
        </div>
      {/each}
    </div>

    <!-- ─── SERVICE PACKAGES ─── -->
    {#if servicePkgs.length > 0}
      <h2 class="section-title" style="margin-top: 5rem;">Bundled Service Packages</h2>
      <div class="bundles-grid">
        {#each servicePkgs as pkg, i}
          <div class="bundle-card card animate-fade" style="animation-delay: {i * 0.1}s">
            {#if pkg.is_roaming}
              <div class="plan-badge roaming">🌍 Roaming Ready</div>
            {:else if pkg.price === 0 || pkg.price === null}
              <div class="plan-badge promo">🎁 Exclusive Deal</div>
            {:else if i === 0}
              <div class="plan-badge trend">🔥 Trending</div>
            {/if}

            <div class="plan-header">
              <h3>{pkg.name}</h3>
              <p class="pkg-subtitle">{pkg.description ?? ''}</p>
              {#if pkg.price !== null}
                <div class="plan-price">
                  <span class="currency">EGP</span>
                  <span class="amount">{pkg.price}</span>
                  <span class="period">per month</span>
                </div>
              {/if}
            </div>

            <div class="plan-features">
              {#if pkg.type === 'voice'}
                <div class="feature-row">
                  <span class="feature-label">📞 Voice</span>
                  <span class="feature-value">{pkg.amount} Min</span>
                </div>
              {:else if pkg.type === 'data'}
                <div class="feature-row">
                  <span class="feature-label">🌐 Data</span>
                  <span class="feature-value">{pkg.amount} MB</span>
                </div>
              {:else if pkg.type === 'sms'}
                <div class="feature-row">
                  <span class="feature-label">💬 SMS</span>
                  <span class="feature-value">{pkg.amount} Msg</span>
                </div>
              {:else if pkg.type === 'free_units'}
                <div class="feature-row">
                  <span class="feature-label">🎁 Free Units</span>
                  <span class="feature-value">{pkg.amount} Units</span>
                </div>
              {/if}
              <div class="feature-row">
                <span class="feature-label">Priority</span>
                <span class="feature-value">{pkg.priority === 1 ? '⚡ High' : '📦 Standard'}</span>
              </div>
            </div>

            <button onclick={() => window.location.href = '/register?pkg=' + pkg.id} class="btn btn-secondary" style="width: 100%; margin-top: 1.5rem;">
              Choose Package
            </button>
          </div>
        {/each}
      </div>
    {/if}
  {/if}
</div>

<style>
  .plan-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 2rem;
    margin-bottom: 4rem;
  }
  .plan-card, .bundle-card {
    padding: 2.5rem 2rem;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    position: relative;
    border-radius: var(--radius-lg);
    background: var(--bg-card);
    border: 1px solid var(--border);
  }
  .plan-header { text-align: center; margin-bottom: 1.5rem; padding-top: 1rem; }
  .plan-header h3 { font-size: 1.5rem; font-weight: 700; color: white; margin-bottom: 0.5rem; }
  
  .plan-price { display: flex; align-items: baseline; justify-content: center; gap: 0.25rem; }
  .currency { font-size: 1rem; color: var(--text-muted); }
  .amount { font-size: 2.5rem; font-weight: 800; color: white; }
  .period { font-size: 0.9rem; color: var(--text-muted); }

  .plan-details, .plan-features {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
    padding: 1.5rem 0;
    border-top: 1px solid var(--border);
    border-bottom: 1px solid var(--border);
    flex: 1;
    margin-bottom: 1.5rem;
  }
  .detail-row, .feature-row { display: flex; justify-content: space-between; font-size: 0.9rem; }
  .detail-label, .feature-label { color: var(--text-muted); }
  .detail-value, .feature-value { color: white; font-weight: 600; }

  .plan-badge {
    position: absolute;
    top: 12px; right: 12px;
    padding: 4px 12px;
    border-radius: 50px;
    font-size: 0.7rem;
    font-weight: 700;
    text-transform: uppercase;
    color: white;
    z-index: 5;
  }
  .popular { background: var(--red); }
  .roaming { background: #3b82f6; }
  .promo { background: #f59e0b; }
  .trend { background: #ef4444; }

  .bundles-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 2rem;
  }
  .pkg-subtitle { font-size: 0.8rem; color: var(--text-muted); margin-top: 0.25rem; }

  @media (max-width: 1024px) {
    .plan-grid, .bundles-grid { grid-template-columns: repeat(2, 1fr); }
  }
  @media (max-width: 768px) {
    .plan-grid, .bundles-grid { grid-template-columns: 1fr; }
  }
</style>