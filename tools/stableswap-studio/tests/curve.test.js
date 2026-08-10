/**
 * Agora StableSwap Math & Arbitrage Unit Tests
 */

import { defaultCurveEngine } from '../src/core/curve-math.js';
import { defaultArbitrageScanner } from '../src/core/arbitrage-scanner.js';

async function runCurveTests() {
  console.log('Testing Agora StableSwap Invariant & Arbitrage Engine...');

  // 1. Test Invariant Output Calculation
  const quote = defaultCurveEngine.calculateSwapOutput('pool_ausd_usdc', 'USDC', 10000);
  if (quote.outputAmount < 9990 || quote.outputAmount > 10010) {
    throw new Error('StableSwap bonding curve output calculation incorrect');
  }

  // 2. Test Swap Execution
  const swap = defaultCurveEngine.executeSwap('pool_ausd_usdc', 'USDC', 10000);
  if (!swap.success || !swap.log.txHash) {
    throw new Error('Swap execution failed');
  }

  // 3. Test Arbitrage Scanner
  const arb = defaultArbitrageScanner.scanOpportunities();
  if (arb.activeOpportunities.length === 0) {
    throw new Error('Arbitrage scanner returned no opportunities');
  }

  console.log(`✅ Agora StableSwap Invariant Math & Arbitrage Scanner Tested!`);
}

runCurveTests().catch(e => {
  console.error('❌ Curve Test Failed:', e);
  process.exit(1);
});
