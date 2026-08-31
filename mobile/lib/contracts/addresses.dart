const int chainId = 4801;
const String chainName = 'World Chain Sepolia';
const String defaultRpcUrl = 'http://8.141.100.69:8085/rpc';
const String storageKeyRpc = 'app_rpc_url';

const String cornTokenAddress = '0x7440503d25a38513919203e58db70d3ee14197ed';
const String predictionMarketAddress = '0x9cb69cb7da9677b3a122a6a4e402398a6df4a026';
const String govCornTokenAddress = '0x3F540371f5E88E3B9625b63411e4ba1FDB4702f0';
const String tokenHouseAddress = '0x70Edf96015fE901c44b6b61Ad5CcB9884B545DE9';
const String humanHouseAddress = '0xd1062855477c08bff3c852fc42844ca35db32c72';

const List<dynamic> cornTokenAbi = [
  'function balanceOf(address owner) view returns (uint256)',
  'function approve(address spender, uint256 amount) returns (bool)',
  'function allowance(address owner, address spender) view returns (uint256)',
  'function totalSupply() view returns (uint256)',
];

const List<dynamic> predictionMarketAbi = [
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
];

const List<dynamic> govCrownTokenAbi = [
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
];

const List<dynamic> tokenHouseAbi = [
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
];

const List<dynamic> humanHouseAbi = [
  'function raiseDispute(uint256 marketId, uint8 disputeType, string reason)',
  'function vote(uint256 disputeId, bool support, uint256 root, uint256 nullifierHash, uint256[8] proof)',
  'function executeDispute(uint256 disputeId)',
  'function disputeDeposit() view returns (uint256)',
  'function votingPeriod() view returns (uint256)',
  'function disputeCount() view returns (uint256)',
  'function disputes(uint256 id) view returns (uint256 marketId, uint8 disputeType, uint8 state, address initiator, uint256 deposit, uint256 deadline, string reason, uint256 votesFor, uint256 votesAgainst)',
];
