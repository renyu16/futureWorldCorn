export const CORN_TOKEN_ADDRESS = '0x6a07C7b64702E67f32d14f55F26dAAc94082B981'
export const PREDICTION_MARKET_ADDRESS = '0xAecA3704114B03d2d85f6EC5C4df83b277A657bb'

export interface ContractAddresses {
  cornToken: `0x${string}`
  predictionMarket: `0x${string}`
  oracleAdapter: `0x${string}`
}

export const DeployedAddresses: Record<number, ContractAddresses> = {
  4801: {
    cornToken: '0x6a07C7b64702E67f32d14f55F26dAAc94082B981',
    predictionMarket: '0xAecA3704114B03d2d85f6EC5C4df83b277A657bb',
    oracleAdapter: '0x617CEC12C21b4D4Def72afAd7858E7596e83dc82',
  },
  480: {
    cornToken: '0x...',
    predictionMarket: '0x...',
    oracleAdapter: '0x...',
  },
}

export function getConfig(chainId: number): ContractAddresses {
  const config = DeployedAddresses[chainId]
  if (!config) {
    throw new Error(`No deployment config found for chain ID ${chainId}`)
  }
  return config
}

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

export const GOV_CORN_TOKEN_ADDRESS = '0x...'

export const govCrownTokenABI = [
  'function depositFor(address account, uint256 amount)',
  'function withdrawTo(address account, uint256 amount)',
  'function delegate(address delegatee)',
  'function getVotes(address account) view returns (uint256)',
  'function balanceOf(address account) view returns (uint256)',
  'function totalSupply() view returns (uint256)',
  'function allowance(address owner, address spender) view returns (uint256)',
  'function approve(address spender, uint256 amount) returns (bool)',
  'function decimals() view returns (uint8)',
  'event Transfer(address indexed from, address indexed to, uint256 value)',
] as const

export const TOKEN_HOUSE_ADDRESS = '0x...'

export const tokenHouseABI = [
  'function state(uint256 proposalId) view returns (uint8)',
  'function proposalProposer(uint256 proposalId) view returns (address)',
  'function proposalDeadline(uint256 proposalId) view returns (uint256)',
  'function proposalSnapshot(uint256 proposalId) view returns (uint256)',
  'function proposalVotes(uint256 proposalId) view returns (uint256 against, uint256 forVotes, uint256 abstain)',
  'function castVote(uint256 proposalId, uint8 support) returns (uint256)',
  'function castVoteWithReason(uint256 proposalId, uint8 support, string reason) returns (uint256)',
  'function propose(address[] targets, uint256[] values, bytes[] calldatas, string description) returns (uint256)',
  'function proposalThreshold() view returns (uint256)',
  'function votingDelay() view returns (uint256)',
  'function votingPeriod() view returns (uint256)',
  'function quorum(uint256 blockNumber) view returns (uint256)',
  'function getVotes(address account, uint256 blockNumber) view returns (uint256)',
  'function hashProposal(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) view returns (uint256)',
  'event ProposalCreated(uint256 proposalId, address proposer, address[] targets, uint256[] values, string[] signatures, bytes[] calldatas, uint256 voteStart, uint256 voteEnd, string description)',
] as const

export const HUMAN_HOUSE_ADDRESS = '0x...'

export const humanHouseABI = [
  'function raiseDispute(uint256 marketId, uint8 disputeType, string reason)',
  'function vote(uint256 disputeId, bool support, uint256 root, uint256 nullifierHash, uint256[8] proof)',
  'function executeDispute(uint256 disputeId)',
  'function disputeDeposit() view returns (uint256)',
  'function votingPeriod() view returns (uint256)',
  'function disputeCount() view returns (uint256)',
  'function disputes(uint256 id) view returns (uint256 marketId, uint8 disputeType, uint8 state, address initiator, uint256 deposit, uint256 deadline, string reason, uint256 votesFor, uint256 votesAgainst)',
  'function nullifierUsed(uint256 disputeId, uint256 nullifierHash) view returns (bool)',
  'event DisputeCreated(uint256 indexed disputeId, uint256 indexed marketId, uint8 disputeType, string reason)',
  'event VoteCast(uint256 indexed disputeId, bool support)',
  'event DisputeExecuted(uint256 indexed disputeId, uint8 outcome, uint256 votesFor, uint256 votesAgainst)',
] as const
