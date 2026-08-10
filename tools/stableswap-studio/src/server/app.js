/**
 * Agora StableSwap Studio Web Server
 */

import express from 'express';
import cors from 'cors';
import path from 'path';
import { fileURLToPath } from 'url';
import { STABLESWAP_CONFIG } from '../config.js';
import { defaultCurveEngine } from '../core/curve-math.js';
import { defaultArbitrageScanner } from '../core/arbitrage-scanner.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const WEB_ROOT = path.join(__dirname, '../../web');

const app = express();
const PORT = process.env.PORT || 3414;

app.use(cors());
app.use(express.json());
app.use(express.static(WEB_ROOT));

// 1. Get Pools & Protocol Info
app.get('/api/pools', (req, res) => {
  res.json({
    protocol: STABLESWAP_CONFIG.protocol,
    pools: defaultCurveEngine.getPools(),
  });
});

// 2. Quote Swap Output
app.post('/api/quote', (req, res) => {
  try {
    const { poolId, inputToken, inputAmount } = req.body;
    const quote = defaultCurveEngine.calculateSwapOutput(poolId, inputToken, inputAmount);
    res.json(quote);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// 3. Execute Swap
app.post('/api/swap', (req, res) => {
  try {
    const { poolId, inputToken, inputAmount, userAddress } = req.body;
    const result = defaultCurveEngine.executeSwap(poolId, inputToken, inputAmount, userAddress);
    res.json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// 4. Arbitrage Scanner
app.get('/api/arbitrage', (req, res) => {
  res.json(defaultArbitrageScanner.scanOpportunities());
});

// 5. Swap History
app.get('/api/history', (req, res) => {
  res.json(defaultCurveEngine.getSwapLogs());
});

if (process.env.NODE_ENV !== 'test') {
  app.listen(PORT, () => {
    console.log(`\n======================================================`);
    console.log(`🌊 Agora StableSwap Multi-Pool Studio Running!`);
    console.log(`🌐 Web Dashboard: http://localhost:${PORT}`);
    console.log(`📊 Invariant: A=200 Low-Slippage Stable Bonding Curve`);
    console.log(`======================================================\n`);
  });
}

export default app;
