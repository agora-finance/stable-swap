#!/usr/bin/env node

/**
 * Agora StableSwap CLI
 */

import { defaultCurveEngine } from '../src/core/curve-math.js';
import { defaultArbitrageScanner } from '../src/core/arbitrage-scanner.js';

const args = process.argv.slice(2);
const command = args[0] || 'help';

async function main() {
  switch (command.toLowerCase()) {
    case 'pools': {
      console.log('\n🌊 Active Agora StableSwap Pools:');
      defaultCurveEngine.getPools().forEach(p => {
        console.log(`  • [${p.id}] ${p.name} (APY: ${p.apy})`);
        console.log(`    Reserves:      ${JSON.stringify(p.reserves)}`);
        console.log(`    Virtual Price: ${p.virtualPrice}\n`);
      });
      break;
    }

    case 'swap': {
      const poolId = args[1] || 'pool_ausd_usdc';
      const token = args[2] || 'USDC';
      const amount = args[3] || '10000';

      console.log(`\n🔄 Executing Agora StableSwap of ${amount} ${token} in ${poolId}...`);
      const res = defaultCurveEngine.executeSwap(poolId, token, amount);
      console.log(`  Swapped:       ${res.log.input} -> ${res.log.output}`);
      console.log(`  Price Impact:  ${res.log.priceImpact}`);
      console.log(`  Fee Paid:      ${res.log.feePaid}`);
      console.log(`  TX Hash:       ${res.log.txHash}\n`);
      break;
    }

    case 'arbitrage': {
      console.log('\n⚡ Scanning Cross-DEX Arbitrage Opportunities...');
      const scan = defaultArbitrageScanner.scanOpportunities();
      scan.activeOpportunities.forEach(o => {
        console.log(`  • ${o.pair} [Spread: ${o.spreadBps} bps]`);
        console.log(`    Route:  ${o.route}`);
        console.log(`    Profit: ${o.estimatedProfitPer100k} per $100k trade\n`);
      });
      break;
    }

    case 'studio': {
      console.log('\n🌐 Launching StableSwap Studio on :3414...');
      await import('../src/server/app.js');
      break;
    }

    default: {
      console.log(`
╔══════════════════════════════════════════════════════════════════╗
║               🌊 AGORA STABLESWAP PROTOCOL CLI                   ║
║       Multi-Pool Invariant Math & Arbitrage Scanner Suite        ║
╚══════════════════════════════════════════════════════════════════╝

Commands:
  stableswap-cli pools                       List active liquidity pools & APY
  stableswap-cli swap [poolId] [token] [amt] Execute low-slippage pool swap
  stableswap-cli arbitrage                   Scan cross-DEX arbitrage spreads
  stableswap-cli studio                      Launch Interactive Web Studio on :3414
      `);
      break;
    }
  }
}

main().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
