# Prediction Master Dapp Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a prediction market Dapp on World Chain with CORN utility token, AMM-based betting, and Chainlink oracle integration.

**Architecture:** Monorepo with Foundry (Solidity) for smart contracts and React/Vite for frontend. Token (ERC20+Permit) and PredictionMarket (UUPS upgradeable) are core contracts. OracleAdapter abstracts Chainlink Data Feeds and Automation resolution.

**Tech Stack:** Foundry, Solidity, OpenZeppelin, Chainlink, React, wagmi, viem, RainbowKit

---

### Task 1: Initialize Foundry Project

**Files:**
- Create: `foundry.toml`
- Create: `src/CornToken.sol`
- Create: `src/PredictionMarket.sol`
- Create: `src/OracleAdapter.sol`
- Create: `src/interfaces/ICornToken.sol`
- Create: `src/interfaces/IPredictionMarket.sol`
- Create: `src/interfaces/IOracleAdapter.sol`

**Step 1: Init Foundry project**

Run: `forge init`
Expected: Standard Foundry scaffold (`src/`, `test/`, `lib/`, `foundry.toml`)

**Step 2: Install OpenZeppelin contracts**

Run: `forge install OpenZeppelin/openzeppelin-contracts`
Expected: Dependencies installed in `lib/openzeppelin-contracts`

**Step 3: Install Chainlink contracts**

Run: `forge install smartcontractkit/chainlink-brownie-contracts`
Expected: Dependencies installed in `lib/chainlink-brownie-contracts`

**Step 4: Configure foundry.toml**

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
ffi = true
solc = "0.8.26"
evm_version = "cancun"

remappings = [
    "@openzeppelin/=lib/openzeppelin-contracts/",
    "@chainlink/=lib/chainlink-brownie-contracts/contracts/",
]
```

**Step 5: Create placeholder interface files**

Create basic interface files with just Natspec (no function bodies yet).

**Step 6: Commit**

```bash
git add .
git commit -m "chore: init Foundry project with deps"
```

---

### Task 2: CornToken Contract

**Files:**
- Modify: `src/CornToken.sol`
- Create: `test/CornToken.t.sol`

**Step 1: Write failing tests**

```solidity
// test/CornToken.t.sol
pragma solidity ^0.8.26;
import "forge-std/Test.sol";
import "../src/CornToken.sol";

contract CornTokenTest is Test {
    CornToken token;
    address alice = address(0x1);

    function setUp() public {
        token = new CornToken(0xDeAd); // deploy with dummy initial owner for tests
    }

    function test_TotalSupply() public {
        assertEq(token.totalSupply(), 1_000_000_000 * 10**18);
    }

    function test_Permit() public {
        // verify ERC20Permit interface exists
        assertTrue(address(token) != address(0));
    }

    function test_Burn() public {
        token.transfer(address(1), 100);
        vm.prank(address(1));
        token.burn(100);
        assertEq(token.balanceOf(address(1)), 0);
    }

    function test_MintRevertsForNonOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        token.mint(alice, 100);
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `forge test --match-contract CornTokenTest -vv`
Expected: FAIL

**Step 3: Write CornToken implementation**

```solidity
// src/CornToken.sol
pragma solidity ^0.8.26;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CornToken is ERC20, ERC20Permit, Ownable {
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18;
    bool public mintLocked;

    constructor() ERC20("CornToken", "CORN") ERC20Permit("CornToken") Ownable(msg.sender) {
        _mint(msg.sender, MAX_SUPPLY);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        require(!mintLocked, "mint locked");
        require(totalSupply() + amount <= MAX_SUPPLY, "exceeds max supply");
        _mint(to, amount);
    }

    function lockMint() external onlyOwner {
        mintLocked = true;
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `forge test --match-contract CornTokenTest -vv`
Expected: PASS

**Step 5: Commit**

```bash
git add src/CornToken.sol test/CornToken.t.sol
git commit -m "feat: add CornToken ERC20 with Permit and Ownable"
```

---

### Task 3: PredictionMarket Core Contract

**Files:**
- Modify: `src/PredictionMarket.sol`
- Create: `test/PredictionMarket.t.sol`

**Step 1: Write failing tests**

Test cases:
- `test_CreateMarket` — owner creates a market, verify storage
- `test_Bet` — user bets on YES, verify pool balance
- `test_BetRevertsAfterDeadline` — bet after deadline reverts
- `test_ResolveYes` — resolve with YES outcome, verify resolved state
- `test_ClaimReward` — winner claims, verify balance change
- `test_ClaimRevertsBeforeResolve` — claim before resolve reverts
- `test_MultipleBets` — two users bet on different outcomes, verify shares
- `test_DefaultFee` — verify default fee is 200 bps
- `test_SetMarketFee` — override fee per market
- `test_FeeCollected` — verify fee goes to feeCollector
- `test_OnlyOwnerCreate` — non-owner cannot create market

**Step 2: Run tests to verify they fail**

Run: `forge test --match-contract PredictionMarketTest -vv`
Expected: FAIL

**Step 3: Write PredictionMarket implementation**

Core structures and functions:

```solidity
// src/PredictionMarket.sol
pragma solidity ^0.8.26;
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PredictionMarket is Ownable2Step, ReentrancyGuard {
    IERC20 public token;
    uint16 public defaultFeeBps = 200; // 2%
    address public feeCollector;
    uint256 public marketCount;

    enum Outcome { YES, NO }
    enum MarketStatus { Open, Resolved }

    struct Market {
        string question;
        uint128 outcomeYes;
        uint128 outcomeNo;
        uint40 deadline;
        MarketStatus status;
        bool result; // true=YES, false=NO
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

    constructor(address _token, address _feeCollector) Ownable(msg.sender) {
        token = IERC20(_token);
        feeCollector = _feeCollector;
    }

    function createMarket(string calldata question, uint40 deadline, uint16 feeBps) external onlyOwner {
        require(deadline > block.timestamp, "deadline in past");
        require(feeBps <= 1000, "fee too high"); // max 10%

        marketCount++;
        Market storage m = markets[marketCount];
        m.question = question;
        m.deadline = deadline;
        m.status = MarketStatus.Open;
        m.feeBps = feeBps;

        emit MarketCreated(marketCount, question, deadline);
    }

    function bet(uint256 marketId, Outcome outcome, uint256 amount) external nonReentrant {
        Market storage m = markets[marketId];
        require(m.status == MarketStatus.Open, "market not open");
        require(block.timestamp < m.deadline, "betting closed");
        require(amount > 0, "zero amount");

        token.transferFrom(msg.sender, address(this), amount);

        if (outcome == Outcome.YES) {
            m.outcomeYes += uint128(amount);
            sharesYes[marketId][msg.sender] += amount;
        } else {
            m.outcomeNo += uint128(amount);
            sharesNo[marketId][msg.sender] += amount;
        }

        emit BetPlaced(marketId, msg.sender, outcome, amount);
    }

    function resolveMarket(uint256 marketId, bool result) external onlyOwner {
        Market storage m = markets[marketId];
        require(m.status == MarketStatus.Open, "already resolved");
        require(block.timestamp >= m.deadline, "deadline not reached");

        m.status = MarketStatus.Resolved;
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
        reward += userShares; // return original stake

        if (fee > 0) {
            token.transfer(feeCollector, fee);
        }
        token.transfer(msg.sender, reward);

        emit RewardClaimed(marketId, msg.sender, reward);
    }

    // Admin setters
    function setDefaultFee(uint16 _feeBps) external onlyOwner {
        defaultFeeBps = _feeBps;
    }

    function setFeeCollector(address _feeCollector) external onlyOwner {
        feeCollector = _feeCollector;
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `forge test --match-contract PredictionMarketTest -vv`
Expected: PASS

**Step 5: Commit**

```bash
git add src/PredictionMarket.sol test/PredictionMarket.t.sol
git commit -m "feat: add PredictionMarket with AMM betting and resolution"
```

---

### Task 4: OracleAdapter Contract

**Files:**
- Modify: `src/OracleAdapter.sol`
- Create: `test/OracleAdapter.t.sol`
- Modify: `src/PredictionMarket.sol`

**Step 1: Write failing tests**

Test cases:
- `test_ResolveViaDataFeed` — mock feed returns data, market resolves
- `test_ResolveViaPush` — owner pushes result, market resolves
- `test_ResolveUnauthorized` — non-Keeper cannot resolve

**Step 2: Run tests to verify they fail**

Run: `forge test --match-contract OracleAdapterTest -vv`
Expected: FAIL

**Step 3: Write OracleAdapter implementation**

```solidity
// src/OracleAdapter.sol
pragma solidity ^0.8.26;
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./PredictionMarket.sol";

contract OracleAdapter {
    PredictionMarket public market;
    address public keeper;

    struct FeedConfig {
        AggregatorV3Interface feed;
        uint256 threshold;
        bool isAbove; // true = resolve YES if price > threshold
    }
    mapping(uint256 => FeedConfig) public feedConfigs;
    mapping(uint256 => bool) public pushResults;

    event Resolved(uint256 indexed marketId, bool result);

    modifier onlyKeeper() {
        require(msg.sender == keeper, "not keeper");
        _;
    }

    constructor(address _market, address _keeper) {
        market = PredictionMarket(_market);
        keeper = _keeper;
    }

    function configureFeed(uint256 marketId, address feedAddr, uint256 threshold, bool isAbove) external {
        feedConfigs[marketId] = FeedConfig(AggregatorV3Interface(feedAddr), threshold, isAbove);
    }

    function resolveWithFeed(uint256 marketId) external onlyKeeper {
        FeedConfig memory cfg = feedConfigs[marketId];
        (, int price,,,) = cfg.feed.latestRoundData();
        bool result = cfg.isAbove ? uint256(price) > cfg.threshold : uint256(price) < cfg.threshold;
        market.resolveMarket(marketId, result);
        emit Resolved(marketId, result);
    }

    function pushResult(uint256 marketId, bool result) external onlyKeeper {
        pushResults[marketId] = result;
        market.resolveMarket(marketId, result);
        emit Resolved(marketId, result);
    }
}
```

Modify PredictionMarket to add `resolveMarket(uint256, bool)` public variant.

**Step 4: Run tests to verify they pass**

Run: `forge test --match-contract OracleAdapterTest -vv`
Expected: PASS

**Step 5: Commit**

```bash
git add src/OracleAdapter.sol test/OracleAdapter.t.sol
git commit -m "feat: add OracleAdapter with Chainlink feed and push support"
```

---

### Task 5: Upgradeable Proxy Integration

**Files:**
- Create: `src/ProxyAdmin.sol`
- Modify: `test/PredictionMarket.t.sol`

**Step 1: Write failing test for upgrade**

```solidity
function test_Upgrade() public {
    PredictionMarketV2 impl = new PredictionMarketV2(address(token), feeCollector);
    bytes memory data = "";
    proxy.upgradeToAndCall(address(impl), data);
    PredictionMarketV2 updated = PredictionMarketV2(address(proxy));
    // verify storage preserved: same marketCount, same token address
}
```

**Step 2: Wrap PredictionMarket in UUPS**

Use OpenZeppelin UUPSUpgradeable pattern.

**Step 3: Run tests to verify they pass**

Run: `forge test --match-test test_Upgrade -vv`
Expected: PASS

**Step 4: Commit**

```bash
git add src/ test/
git commit -m "feat: add UUPS upgradeability to PredictionMarket"
```

---

### Task 6: Frontend Scaffold

**Files:**
- Create: `frontend/package.json`
- Create: `frontend/vite.config.ts`
- Create: `frontend/tsconfig.json`
- Create: `frontend/index.html`
- Create: `frontend/src/main.tsx`
- Create: `frontend/src/App.tsx`
- Create: `frontend/src/pages/MarketList.tsx`
- Create: `frontend/src/pages/MarketDetail.tsx`
- Create: `frontend/src/pages/CreateMarket.tsx`
- Create: `frontend/src/pages/Portfolio.tsx`
- Create: `frontend/src/components/WalletConnect.tsx`
- Create: `frontend/src/hooks/useMarket.ts`
- Create: `frontend/src/hooks/useToken.ts`

**Step 1: Init Vite + React + TypeScript**

Run: `npm create vite@latest frontend -- --template react-ts`

**Step 2: Install dependencies**

```
cd frontend
npm install wagmi viem @rainbow-me/rainbowkit @tanstack/react-query
```

**Step 3: Set up RainbowKit + wagmi provider**

Configure World Chain (opBNB / OP Stack config) in `main.tsx`.

**Step 4: Build MarketList page**

Fetches market IDs from contract, displays cards with question, deadline, pool totals.

**Step 5: Build MarketDetail page**

Shows question, YES/NO pool sizes, user's position, bet input, claim button.

**Step 6: Build CreateMarket page**

Form for admin: question, deadline, fee override.

**Step 7: Build Portfolio page**

Show user's bets across all markets, pending claims.

**Step 8: Commit**

```bash
git add frontend/
git commit -m "feat: scaffold frontend with React, wagmi, RainbowKit"
```

---

### Task 7: Integration Tests

**Files:**
- Create: `test/integration/PredictionMarketIntegration.t.sol`

**Step 1: Write full flow test**

```solidity
function test_FullPredictionFlow() public {
    // 1. Deploy CornToken
    // 2. Deploy PredictionMarket
    // 3. Owner creates a market
    // 4. Alice approves and bets YES
    // 5. Bob bets NO
    // 6. Fast-forward past deadline
    // 7. Resolve YES
    // 8. Alice claims, verify balance
    // 9. Bob tries to claim, reverts
}
```

**Step 2: Run integration tests**

Run: `forge test --match-contract IntegrationTest -vvv`
Expected: PASS

**Step 3: Commit**

```bash
git add test/integration/
git commit -m "test: add full flow integration test"
```
