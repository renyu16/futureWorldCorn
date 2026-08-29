import { parseAbi } from 'viem'
import { ADDRESSES, getConfig } from '../config'

// 合约地址统一在 src/config.ts 管理（双链 + 环境变量覆盖），此处仅导出当前构建的值。
// 正式上线：改 frontend/.env 后重新构建即可切换，无需改源码（详见 config.ts 顶部注释）。
export const CORN_TOKEN_ADDRESS = ADDRESSES.cornToken as `0x${string}`
export const PREDICTION_MARKET_ADDRESS = ADDRESSES.predictionMarket as `0x${string}`

export { getConfig }

export const cornTokenABI = parseAbi([
  'function balanceOf(address owner) view returns (uint256)',
  'function approve(address spender, uint256 amount) returns (bool)',
  'function transfer(address to, uint256 amount) returns (bool)',
  'function transferFrom(address from, address to, uint256 amount) returns (bool)',
  'function allowance(address owner, address spender) view returns (uint256)',
  'function totalSupply() view returns (uint256)',
  'function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)',
  'event Transfer(address indexed from, address indexed to, uint256 value)',
  'event Approval(address indexed owner, address indexed spender, uint256 value)',
])

export const predictionMarketABI = parseAbi([
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
  'function owner() view returns (address)',
  'event MarketCreated(uint256 indexed id, string question, uint40 deadline)',
  'event BetPlaced(uint256 indexed id, address indexed user, uint8 outcome, uint256 amount)',
  'event MarketResolved(uint256 indexed id, bool result)',
  'event RewardClaimed(uint256 indexed id, address indexed user, uint256 amount)',
])

export const GOV_CORN_TOKEN_ADDRESS = ADDRESSES.govCornToken as `0x${string}`

export const govCrownTokenABI = parseAbi([
  'function depositFor(address account, uint256 amount)',
  'function withdrawTo(address account, uint256 amount)',
  'function delegate(address delegatee)',
  'function getVotes(address account) view returns (uint256)',
  'function balanceOf(address account) view returns (uint256)',
  'function totalSupply() view returns (uint256)',
  'function allowance(address owner, address spender) view returns (uint256)',
  'function approve(address spender, uint256 amount) returns (bool)',
  'function decimals() view returns (uint8)',
  'function delegates(address account) view returns (address)',
  'event Transfer(address indexed from, address indexed to, uint256 value)',
  'event DelegateChanged(address indexed delegator, address indexed fromDelegate, address toDelegate)',
])

export const TOKEN_HOUSE_ADDRESS = ADDRESSES.tokenHouse as `0x${string}`

export const tokenHouseABI = parseAbi([
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
  'event ProposalCreated(uint256 indexed proposalId, address indexed proposer, address[] targets, uint256[] values, string[] signatures, bytes[] calldatas, uint256 voteStart, uint256 voteEnd, string description)',
])

export const HUMAN_HOUSE_ADDRESS = ADDRESSES.humanHouse as `0x${string}`

export const humanHouseABI = parseAbi([
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
])
