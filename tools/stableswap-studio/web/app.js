/**
 * Agora StableSwap Studio Client Logic
 */

let pools = [];

document.addEventListener('DOMContentLoaded', () => {
  initTabs();
  loadPools();
  loadArbitrage();
  loadHistory();
  initFormListeners();
});

function initTabs() {
  const tabs = document.querySelectorAll('.nav-tab');
  tabs.forEach(tab => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('.nav-tab').forEach(t => t.classList.toggle('active', t === tab));
      document.querySelectorAll('.tab-pane').forEach(p => p.classList.toggle('active', p.id === `tab-${tab.dataset.tab}`));
    });
  });
}

async function loadPools() {
  try {
    const res = await fetch('/api/pools');
    const data = await res.json();
    pools = data.pools;

    const selectPool = document.getElementById('select-pool');
    const poolsGrid = document.getElementById('pools-container');

    selectPool.innerHTML = '';
    poolsGrid.innerHTML = '';

    pools.forEach((p, idx) => {
      // Option
      const opt = document.createElement('option');
      opt.value = p.id;
      opt.textContent = `${p.name} (APY: ${p.apy})`;
      selectPool.appendChild(opt);

      // Card
      const card = document.createElement('div');
      card.className = 'pool-card';
      card.innerHTML = `
        <div class="pool-title">${p.name}</div>
        <div class="pool-type">${p.type}</div>
        <div class="mt-2 text-muted" style="font-size: 0.82rem;">Virtual Price: <strong>${p.virtualPrice}</strong></div>
        <div class="mt-1" style="font-size: 0.9rem; font-weight: 700; color: #34d399;">APY: ${p.apy}</div>
      `;
      poolsGrid.appendChild(card);
    });

    updateTokensForPool(pools[0]);
    selectPool.addEventListener('change', () => {
      const selected = pools.find(p => p.id === selectPool.value);
      updateTokensForPool(selected);
    });
  } catch (e) {
    console.error(e);
  }
}

function updateTokensForPool(pool) {
  if (!pool) return;
  const selectToken = document.getElementById('swap-in-token');
  selectToken.innerHTML = '';
  pool.tokens.forEach(t => {
    const opt = document.createElement('option');
    opt.value = t;
    opt.textContent = t;
    selectToken.appendChild(opt);
  });
  updateQuote();
}

async function updateQuote() {
  const poolId = document.getElementById('select-pool').value;
  const inputToken = document.getElementById('swap-in-token').value;
  const inputAmount = document.getElementById('swap-in-amount').value;

  if (!poolId || !inputToken || !inputAmount) return;

  try {
    const res = await fetch('/api/quote', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ poolId, inputToken, inputAmount }),
    });
    const quote = await res.json();

    document.getElementById('quote-output').textContent = `${quote.outputAmount.toLocaleString()} ${quote.outputToken}`;
    document.getElementById('quote-impact').textContent = quote.priceImpact;
    document.getElementById('quote-fee').textContent = quote.feePaid;
  } catch (e) {
    console.warn(e);
  }
}

function initFormListeners() {
  document.getElementById('swap-in-amount').addEventListener('input', updateQuote);
  document.getElementById('swap-in-token').addEventListener('change', updateQuote);

  document.getElementById('swap-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const btn = document.getElementById('btn-exec-swap');
    const resultBox = document.getElementById('swap-result-box');

    const poolId = document.getElementById('select-pool').value;
    const inputToken = document.getElementById('swap-in-token').value;
    const inputAmount = document.getElementById('swap-in-amount').value;

    btn.disabled = true;
    btn.textContent = '⏳ Executing Stable Invariant Swap...';

    try {
      const res = await fetch('/api/swap', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ poolId, inputToken, inputAmount }),
      });
      const data = await res.json();

      if (data.success) {
        resultBox.innerHTML = `
          <div class="card" style="border-color: #06b6d4; background: rgba(6, 182, 212, 0.08);">
            <strong style="color: #67e8f9;">🌊 StableSwap Completed!</strong>
            <p class="mt-2" style="font-size: 0.9rem;">Swapped <strong>${data.log.input}</strong> for <strong style="color: #34d399;">${data.log.output}</strong></p>
            <div class="mono text-muted mt-1" style="font-size: 0.75rem;">TX: ${data.log.txHash}</div>
          </div>
        `;
        loadHistory();
      }
    } catch (err) {
      resultBox.innerHTML = `<div class="badge red">Swap error: ${err.message}</div>`;
    } finally {
      btn.disabled = false;
      btn.textContent = '🌊 Execute StableSwap';
    }
  });

  document.getElementById('btn-refresh-arb').addEventListener('click', () => loadArbitrage());
}

async function loadArbitrage() {
  try {
    const res = await fetch('/api/arbitrage');
    const data = await res.json();
    const container = document.getElementById('arb-container');

    container.innerHTML = '';
    data.activeOpportunities.forEach(opp => {
      const card = document.createElement('div');
      card.className = 'arb-card';
      card.innerHTML = `
        <div>
          <div style="font-size: 1.1rem; font-weight: 700; color: #fff;">${opp.pair}</div>
          <div class="text-muted mt-1" style="font-size: 0.85rem;">${opp.route}</div>
        </div>
        <div style="text-align: right;">
          <div style="font-size: 1.15rem; font-weight: 800; color: #34d399;">+${opp.spreadBps} bps Spread</div>
          <div class="text-muted" style="font-size: 0.78rem;">Est. Profit: ${opp.estimatedProfitPer100k}</div>
        </div>
      `;
      container.appendChild(card);
    });
  } catch (e) {
    console.error(e);
  }
}

async function loadHistory() {
  try {
    const res = await fetch('/api/history');
    const logs = await res.json();
    const list = document.getElementById('swaps-history-list');

    if (!logs || logs.length === 0) return;
    list.innerHTML = '';

    logs.forEach(l => {
      const row = document.createElement('div');
      row.className = 'ledger-row';
      row.innerHTML = `
        <div>
          <div style="font-weight: 600;">${l.input} → <span style="color: #34d399;">${l.output}</span></div>
          <div class="mono text-muted" style="font-size: 0.72rem;">${l.poolName}</div>
        </div>
        <div style="text-align: right;">
          <div style="color: #67e8f9; font-weight: 700; font-size: 0.8rem;">Impact: ${l.priceImpact}</div>
          <div class="text-muted" style="font-size: 0.75rem;">${new Date(l.timestamp).toLocaleTimeString()}</div>
        </div>
      `;
      list.appendChild(row);
    });
  } catch (e) {
    console.warn(e);
  }
}
