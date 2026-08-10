/**
 * StableSwap Invariant Mathematics & Execution
 */

import crypto from 'crypto';
import { STABLESWAP_CONFIG } from '../config.js';

export class StableSwapMathEngine {
  constructor() {
    this.pools = new Map();
    STABLESWAP_CONFIG.pools.forEach(p => this.pools.set(p.id, { ...p, reserves: { ...p.reserves } }));
    this.swapLogs = [];
  }

  /**
   * Calculate output amount using StableSwap bonding curve
   */
  calculateSwapOutput(poolId, inputToken, inputAmount) {
    const pool = this.pools.get(poolId);
    if (!pool) throw new Error('Pool not found');

    const outputToken = pool.tokens.find(t => t.toUpperCase() !== inputToken.toUpperCase());
    const inReserve = pool.reserves[inputToken.toUpperCase()];
    const outReserve = pool.reserves[outputToken.toUpperCase()];

    const dx = parseFloat(inputAmount);
    // StableSwap low slippage approximation: dy = dx * (1 - (dx / (2 * A * totalReserve)))
    const A = STABLESWAP_CONFIG.protocol.amplificationCoefficient;
    const totalRes = inReserve + outReserve;
    const priceImpactPct = (dx / (2 * A * totalRes)) * 100;

    const fee = dx * STABLESWAP_CONFIG.protocol.feeRate;
    const dy = (dx - (dx * priceImpactPct / 100) - fee).toFixed(4);

    return {
      inputToken: inputToken.toUpperCase(),
      outputToken: outputToken.toUpperCase(),
      inputAmount: dx,
      outputAmount: parseFloat(dy),
      priceImpact: `${priceImpactPct.toFixed(4)}%`,
      feePaid: `${fee.toFixed(4)} ${inputToken}`,
    };
  }

  /**
   * Execute StableSwap
   */
  executeSwap(poolId, inputToken, inputAmount, userAddress = null) {
    const pool = this.pools.get(poolId);
    if (!pool) throw new Error('Pool not found');

    const calc = this.calculateSwapOutput(poolId, inputToken, inputAmount);

    // Update pool reserves
    pool.reserves[calc.inputToken] += calc.inputAmount;
    pool.reserves[calc.outputToken] -= calc.outputAmount;

    const txHash = '0x' + crypto.randomBytes(32).toString('hex');
    const log = {
      id: `swp_${Date.now()}`,
      poolId,
      poolName: pool.name,
      userAddress: userAddress || '0x' + crypto.randomBytes(20).toString('hex'),
      input: `${calc.inputAmount} ${calc.inputToken}`,
      output: `${calc.outputAmount} ${calc.outputToken}`,
      priceImpact: calc.priceImpact,
      feePaid: calc.feePaid,
      txHash,
      timestamp: new Date().toISOString(),
      status: 'settled_on_chain',
    };

    this.swapLogs.unshift(log);
    this.pools.set(poolId, pool);

    return { success: true, log, poolReserves: pool.reserves };
  }

  getPools() {
    return Array.from(this.pools.values());
  }

  getSwapLogs() {
    return this.swapLogs;
  }
}

export const defaultCurveEngine = new StableSwapMathEngine();
