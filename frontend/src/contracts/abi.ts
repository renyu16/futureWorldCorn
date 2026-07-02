export const CORN_TOKEN_ADDRESS = '0x...'
export const PREDICTION_MARKET_ADDRESS = '0x...'

export const cornTokenABI = [
  'function balanceOf(address owner) view returns (uint256)',
  'function approve(address spender, uint256 amount) returns (bool)',
  'function transfer(address to, uint256 amount) returns (bool)',
  'function transferFrom(address from, address to, uint256 amount) returns (bool)',
  'function allowance(address owner, address spender) view returns (uint256)',
  'function totalSupply() view returns (uint256)',
  'function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)',
  'event Transfer(address indexed from, address indexed to, uint256 value)',
  'event Approval(address indexed owner, address indexed spender, uint256 value)',
] as const

export const predictionMarketABI = [
  'function createMarket(string question, uint40 deadline, uint16 feeBps)',
  'function bet(uint256 marketId, uint8 outcome, uint256 amount)',
  'function resolveMarket(uint256 marketId, bool result)',
  'function claimReward(uint256 marketId)',
  'function marketCount() view returns (uint256)',
  'function markets(uint256 id) view returns (string question, uint128 outcomeYes, uint128 outcomeNo, uint40 deadline, uint8 status, bool result, uint16 feeBps)',
  'function sharesYes(uint256 marketId, address user) view returns (uint256)',
  'function sharesNo(uint256 marketId, address user) view returns (uint256)',
  'function claimed(uint256 marketId, address user) view returns (bool)',
  'function token() view returns (address)',
  'function defaultFeeBps() view returns (uint16)',
  'function feeCollector() view returns (address)',
  'function resolvers(address) view returns (bool)',
  'event MarketCreated(uint256 indexed id, string question, uint40 deadline)',
  'event BetPlaced(uint256 indexed id, address indexed user, uint8 outcome, uint256 amount)',
  'event MarketResolved(uint256 indexed id, bool result)',
  'event RewardClaimed(uint256 indexed id, address indexed user, uint256 amount)',
] as const
