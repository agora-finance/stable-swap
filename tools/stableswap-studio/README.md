# 🌊 Agora StableSwap Studio & Invariant Engine

A multi-pool liquidity simulator, **StableSwap Invariant Engine ($A = 200$)**, and **Cross-DEX Arbitrage Scanner** for the **Agora StableSwap Protocol** (AUSD).

---

## 🌟 Key Features

- 🌊 **Stable Invariant Bonding Curve**: Simulate low-slippage trades across AUSD/USDC, AUSD/USDT, and AUSD/USDY RWA pools.
- ⚡ **Cross-DEX Arbitrage Scanner**: Detect real-time price spreads and arbitrage routes between Curve, Uniswap, and Agora StableSwap.
- 🌐 **Interactive Web Studio**: Real-time DEX terminal, quotes router, and LP APY inspector on `http://localhost:3414`.
- ⌨️ **Universal CLI (`stableswap-cli`)**: Terminal utility for quotes, swaps, and arbitrage scanning.

---

## 🚀 Quickstart

```bash
# Launch StableSwap Studio
npm start
# Open http://localhost:3414

# Or run via CLI
node bin/stableswap-cli.js pools
node bin/stableswap-cli.js arbitrage
node bin/stableswap-cli.js swap pool_ausd_usdc USDC 10000
```
