// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "openzeppelin-contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PredictionMarket is
    Ownable2StepUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    IERC20 public token;
    uint16 public defaultFeeBps;
    address public feeCollector;
    uint256 public marketCount;
    mapping(address => bool) public resolvers;

    enum Outcome { YES, NO }
    enum MarketStatus { Open, Resolved }

    struct Market {
        string question;
        uint128 outcomeYes;
        uint128 outcomeNo;
        uint40 deadline;
        MarketStatus status;
        bool result;
        uint16 feeBps;
    }

    mapping(uint256 => Market) public markets;
    mapping(uint256 => mapping(address => uint256)) public sharesYes;
    mapping(uint256 => mapping(address => uint256)) public sharesNo;
    mapping(uint256 => mapping(address => bool)) public claimed;

    event MarketCreated(uint256 indexed id, string question, uint40 deadline);
    event BetPlaced(uint256 indexed id, address indexed user, Outcome outcome, uint256 amount);
    event MarketResolved(uint256 indexed id, bool result);
    event RewardClaimed(uint256 indexed id, address indexed user, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _token, address _feeCollector, address _initialOwner)
        external
        initializer
    {
        __Ownable_init(_initialOwner);
        __Ownable2Step_init();
        __ReentrancyGuard_init();

        token = IERC20(_token);
        feeCollector = _feeCollector;
        defaultFeeBps = 200;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function createMarket(string calldata question, uint40 deadline, uint16 feeBps) external onlyOwner {
        require(deadline > block.timestamp, "deadline in past");
        uint16 marketFee = feeBps == 0 ? defaultFeeBps : feeBps;
        require(marketFee <= 1000, "fee too high");

        marketCount++;
        Market storage m = markets[marketCount];
        m.question = question;
        m.deadline = deadline;
        m.status = MarketStatus.Open;
        m.feeBps = marketFee;

        emit MarketCreated(marketCount, question, deadline);
    }

    function bet(uint256 marketId, Outcome outcome, uint256 amount) external nonReentrant {
        Market storage m = markets[marketId];
        require(m.status == MarketStatus.Open, "market not open");
        require(block.timestamp < m.deadline, "betting closed");
        require(amount > 0, "zero amount");

        if (outcome == Outcome.YES) {
            m.outcomeYes += uint128(amount);
            sharesYes[marketId][msg.sender] += amount;
        } else {
            m.outcomeNo += uint128(amount);
            sharesNo[marketId][msg.sender] += amount;
        }

        token.safeTransferFrom(msg.sender, address(this), amount);

        emit BetPlaced(marketId, msg.sender, outcome, amount);
    }

    function setResolver(address resolver, bool active) external onlyOwner {
        resolvers[resolver] = active;
    }

    function resolveMarket(uint256 marketId, bool result) external {
        require(msg.sender == owner() || resolvers[msg.sender], "unauthorized");
        Market storage m = markets[marketId];
        require(m.status == MarketStatus.Open, "already resolved");
        require(block.timestamp >= m.deadline, "deadline not reached");

        m.status = MarketStatus.Resolved;
        m.result = result;

        emit MarketResolved(marketId, result);
    }

    function disputeResolve(uint256 marketId, bool result) external {
        require(resolvers[msg.sender], "unauthorized: not a resolver");
        Market storage m = markets[marketId];
        require(m.status == MarketStatus.Resolved, "market not yet resolved");

        m.result = result;

        emit MarketResolved(marketId, result);
    }

    function claimReward(uint256 marketId) external nonReentrant {
        Market storage m = markets[marketId];
        require(m.status == MarketStatus.Resolved, "not resolved");
        require(!claimed[marketId][msg.sender], "already claimed");

        uint256 userShares;
        uint256 losingPool;
        uint256 winningPool;

        if (m.result) {
            userShares = sharesYes[marketId][msg.sender];
            winningPool = m.outcomeYes;
            losingPool = m.outcomeNo;
        } else {
            userShares = sharesNo[marketId][msg.sender];
            winningPool = m.outcomeNo;
            losingPool = m.outcomeYes;
        }

        require(userShares > 0, "no winnings");

        claimed[marketId][msg.sender] = true;

        uint256 fee = (losingPool * m.feeBps) / 10000;
        uint256 rewardPool = losingPool - fee;
        uint256 reward = (userShares * rewardPool) / winningPool;
        reward += userShares;

        if (fee > 0) {
            token.safeTransfer(feeCollector, fee);
        }
        token.safeTransfer(msg.sender, reward);

        emit RewardClaimed(marketId, msg.sender, reward);
    }

    function setDefaultFee(uint16 _feeBps) external onlyOwner {
        defaultFeeBps = _feeBps;
    }

    function setFeeCollector(address _feeCollector) external onlyOwner {
        feeCollector = _feeCollector;
    }

    uint256[50] private __gap;
}
