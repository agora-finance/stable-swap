/**
 * Agora StableSwap Pools & Invariant Configuration
 */

export const STABLESWAP_CONFIG = {
  protocol: {
    name: 'Agora StableSwap',
    amplificationCoefficient: 200, // A parameter
    feeRate: 0.0004, // 0.04% pool swap fee
    adminFeeShare: 0.5, // 50% to AUSD Treasury
  },
  pools: [
    {
      id: 'pool_ausd_usdc',
      name: 'AUSD / USDC Primary Pool',
      type: 'Classic StableSwap (2-Pool)',
      tokens: ['AUSD', 'USDC'],
      reserves: { AUSD: 45000000, USDC: 45200000 },
      virtualPrice: 1.0008,
      volume24h: 18450000,
      apy: '6.85%',
    },
    {
      id: 'pool_ausd_usdt',
      name: 'AUSD / USDT Deep Liquidity',
      type: 'Classic StableSwap (2-Pool)',
      tokens: ['AUSD', 'USDT'],
      reserves: { AUSD: 30000000, USDT: 29950000 },
      virtualPrice: 1.0004,
      volume24h: 12100000,
      apy: '7.12%',
    },
    {
      id: 'pool_ausd_usdy',
      name: 'AUSD / USDY (Ondo RWA Pool)',
      type: 'Yield-Bearing StableSwap',
      tokens: ['AUSD', 'USDY'],
      reserves: { AUSD: 15000000, USDY: 14850000 },
      virtualPrice: 1.0520,
      volume24h: 5200000,
      apy: '9.45%',
    },
  ],
};
