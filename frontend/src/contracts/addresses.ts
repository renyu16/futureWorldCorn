export interface ContractAddresses {
  cornToken: `0x${string}`
  predictionMarket: `0x${string}`
  oracleAdapter: `0x${string}`
}

export const addresses: Record<number, ContractAddresses> = {
  // World Chain Sepolia testnet
  4801: {
    cornToken: '0x...',
    predictionMarket: '0x...',
    oracleAdapter: '0x...',
  },
  // World Chain mainnet
  480: {
    cornToken: '0x...',
    predictionMarket: '0x...',
    oracleAdapter: '0x...',
  },
}
