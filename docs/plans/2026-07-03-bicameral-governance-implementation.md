# Bicameral Governance Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add Phases 2 and 3 governance to Prediction Master: TimelockController, GovCORN wrapper token, TokenHouse (OZ Governor), and HumanHouse (World ID dispute resolution).

**Architecture:** Phase 2 introduces GovCrownToken (ERC20Votes wrapper around CORN) and transfers PredictionMarket ownership to TimelockController backed by Safe multisig. Phase 3 adds bicameral governance: TokenHouse (OZ Governor, govCORN-weighted) and HumanHouse (World ID, one-person-one-vote) as dual proposers on TimelockController.

**Tech Stack:** Solidity 0.8.26, Foundry, OpenZeppelin (Governor, TimelockController, ERC20Votes, ERC20Wrapper), Safe, World ID

---

### Task 1: GovCrownToken Contract

**Files:**
- Create: `src/GovCrownToken.sol`
- Create: `test/GovCrownToken.t.sol`

**Step 1: Write the failing test**

```solidity
// test/GovCrownToken.t.sol
pragma solidity ^0.8.26;
import "forge-std/Test.sol";
import "../src/CornToken.sol";
import "../src/GovCrownToken.sol";

contract GovCrownTokenTest is Test {
    CornToken corn;
    GovCrownToken govCorn;
    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        corn = new CornToken();
        govCorn = new GovCrownToken(address(corn));
        corn.transfer(alice, 1000e18);
    }

    function test_DepositAndWithdraw() public {
        vm.startPrank(alice);
        corn.approve(address(govCorn), 500e18);
        govCorn.depositFor(alice, 500e18);
        assertEq(govCorn.balanceOf(alice), 500e18);
        assertEq(corn.balanceOf(alice), 500e18);

        govCorn.withdrawTo(alice, 200e18);
        assertEq(govCorn.balanceOf(alice), 300e18);
        assertEq(corn.balanceOf(alice), 700e18);
        vm.stopPrank();
    }

    function test_DelegationGrantsVotes() public {
        vm.startPrank(alice);
        corn.approve(address(govCorn), 500e18);
        govCorn.depositFor(alice, 500e18);
        govCorn.delegate(alice);
        assertEq(govCorn.getVotes(alice), 500e18);
        vm.stopPrank();
    }

    function test_DelegateToOther() public {
        vm.startPrank(alice);
        corn.approve(address(govCorn), 500e18);
        govCorn.depositFor(alice, 500e18);
        govCorn.delegate(bob);
        vm.stopPrank();
        assertEq(govCorn.getVotes(bob), 500e18);
        assertEq(govCorn.getVotes(alice), 0);
    }

    function test_NameAndSymbol() public {
        assertEq(govCorn.name(), "Governance Crown Token");
        assertEq(govCorn.symbol(), "govCORN");
    }
}
```

**Step 2: Run test to verify it fails**

Run: `forge test --match-contract GovCrownTokenTest -vvv`
Expected: FAIL (file not found or compile error since GovCrownToken doesn't exist)

**Step 3: Write minimal implementation**

```solidity
// src/GovCrownToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Wrapper.sol";

contract GovCrownToken is ERC20Permit, ERC20Votes, ERC20Wrapper {
    constructor(IERC20 _underlying)
        ERC20("Governance Crown Token", "govCORN")
        ERC20Permit("Governance Crown Token")
        ERC20Wrapper(_underlying)
    {}

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }

    function decimals()
        public view override(ERC20, ERC20Wrapper)
        returns (uint8)
    {
        return ERC20Wrapper.decimals();
    }
}
```

**Step 4: Run test to verify it passes**

Run: `forge test --match-contract GovCrownTokenTest -vvv`
Expected: ALL 4 tests PASS

**Step 5: Commit**

```bash
git add src/GovCrownToken.sol test/GovCrownToken.t.sol
git commit -m "feat: add GovCrownToken ERC20Votes wrapper"
```

---

### Task 2: Deploy Script for Safe + TimelockController

**Files:**
- Create: `script/TransferToTimelock.s.sol`
- Modify: `Makefile`

**Step 1: Write the deploy script**

```solidity
// script/TransferToTimelock.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "forge-std/Script.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "../src/CornToken.sol";
import "../src/PredictionMarket.sol";

contract TransferToTimelock is Script {
    function run() external {
        address deployer = vm.addr(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        address safeAddress = vm.envAddress("SAFE_ADDRESS");
        address marketProxy = vm.envAddress("MARKET_PROXY");
        address tokenAddress = vm.envAddress("CORN_TOKEN");
        uint256 minDelay = vm.envOr("TIMELOCK_DELAY", uint256(2 days));

        vm.startBroadcast();

        TimelockController timelock = new TimelockController(
            minDelay,
            new address[](0),    // proposers — empty, will be set later
            new address[](0),    // executors — empty, anyone can execute
            deployer             // admin — temporarily deployer
        );

        // Grant proposer role to Safe
        timelock.grantRole(timelock.PROPOSER_ROLE(), safeAddress);
        // Grant executor role to anyone
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        // Renounce admin — timelock becomes self-administered
        timelock.revokeRole(timelock.TIMELOCK_ADMIN_ROLE(), deployer);
        timelock.grantRole(timelock.TIMELOCK_ADMIN_ROLE(), address(timelock));

        // Transfer PredictionMarket owner to Timelock
        PredictionMarket market = PredictionMarket(marketProxy);
        market.transferOwnership(address(timelock));

        // Transfer CornToken owner to Timelock
        CornToken token = CornToken(tokenAddress);
        token.transferOwnership(address(timelock));

        vm.stopBroadcast();
    }
}
```

**Step 2: Verify the script compiles**

Run: `forge build`
Expected: No errors

**Step 3: Commit**

```bash
git add script/TransferToTimelock.s.sol
git commit -m "feat: add deploy script for TimelockController ownership transfer"
```

---

### Task 3: HumanHouse Contract

**Files:**
- Create: `src/HumanHouse.sol`
- Create: `test/HumanHouse.t.sol`

**Step 1: Write the failing test**

```solidity
// test/HumanHouse.t.sol
pragma solidity ^0.8.26;
import "forge-std/Test.sol";
import "../src/HumanHouse.sol";
import "../src/CornToken.sol";
import "../src/PredictionMarket.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract HumanHouseTest is Test {
    CornToken corn;
    PredictionMarket market;
    HumanHouse humanHouse;
    address feeCollector = address(0x99);
    address alice = address(0x1);

    function setUp() public {
        corn = new CornToken();
        PredictionMarket impl = new PredictionMarket();
        bytes memory initData = abi.encodeWithSelector(
            PredictionMarket.initialize.selector, address(corn), feeCollector, address(this)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        market = PredictionMarket(address(proxy));

        // Create a market
        market.createMarket("Will ETH reach $10k?", uint40(block.timestamp + 7 days), 0);
        // Deposit CORN to market
        corn.transfer(alice, 10000e18);
        vm.startPrank(alice);
        corn.approve(address(market), 1000e18);
        market.bet(1, PredictionMarket.Outcome.YES, 1000e18);
        vm.stopPrank();

        // Deploy HumanHouse
        humanHouse = new HumanHouse(address(corn), address(market), 1000e18);
    }

    function test_DisputeLifecycle() public {
        // Resolve market as YES
        market.resolveMarket(1, true);

        // Alice disputes the result (in real flow this would use World ID proof)
        // For testing, we skip World ID by using a mock

        // In production, dispute requires:
        // - World ID proof (root, nullifierHash, proof)
        // - 1000 CORN deposit
        vm.startPrank(alice);
        corn.approve(address(humanHouse), 1000e18);
        // This would need World ID proofs — test will be updated after World ID integration
        humanHouse.raiseDispute{value: 0}(
            1,
            HumanHouse.DisputeType.OracleResult,
            "Price feed was incorrect"
        );
        vm.stopPrank();

        // Dispute created — check state
        (,,, HumanHouse.DisputeState state,,,,) = humanHouse.disputes(1);
        assertEq(uint8(state), uint8(HumanHouse.DisputeState.Active));
    }
}
```

**Step 2: Run test to verify it fails**

Run: `forge test --match-contract HumanHouseTest -vvv`
Expected: FAIL

**Step 3: Write implementation**

```solidity
// src/HumanHouse.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract HumanHouse is Pausable {
    using SafeERC20 for IERC20;

    enum DisputeType { OracleResult, MarketContent }
    enum DisputeState { Active, Approved, Rejected }

    struct Dispute {
        uint256 marketId;
        DisputeType disputeType;
        DisputeState state;
        address initiator;
        uint256 deposit;
        uint256 deadline;
        string reason;
        uint256 votesFor;
        uint256 votesAgainst;
    }

    IERC20 public cornToken;
    address public predictionMarket;
    uint256 public disputeDeposit;
    uint256 public votingPeriod = 5 days;
    uint256 public disputeCount;

    mapping(uint256 => Dispute) public disputes;
    mapping(uint256 => mapping(uint256 => bool)) public hasVoted; // disputeId => nullifierHash => voted

    event DisputeCreated(uint256 indexed disputeId, uint256 indexed marketId, DisputeType disputeType, string reason);
    event VoteCast(uint256 indexed disputeId, bool support);
    event DisputeExecuted(uint256 indexed disputeId, DisputeState outcome);

    constructor(address _cornToken, address _predictionMarket, uint256 _disputeDeposit) {
        cornToken = IERC20(_cornToken);
        predictionMarket = _predictionMarket;
        disputeDeposit = _disputeDeposit;
    }

    function raiseDispute(
        uint256 marketId,
        DisputeType disputeType,
        string calldata reason
    ) external whenNotPaused {
        cornToken.safeTransferFrom(msg.sender, address(this), disputeDeposit);

        disputeCount++;
        disputes[disputeCount] = Dispute({
            marketId: marketId,
            disputeType: disputeType,
            state: DisputeState.Active,
            initiator: msg.sender,
            deposit: disputeDeposit,
            deadline: block.timestamp + votingPeriod,
            reason: reason,
            votesFor: 0,
            votesAgainst: 0
        });

        emit DisputeCreated(disputeCount, marketId, disputeType, reason);
    }

    // Note: World ID verification will be added in integration.
    // For now, _verifyWorldId is a placeholder that always passes.
    function vote(
        uint256 disputeId,
        bool support
    ) external whenNotPaused {
        Dispute storage d = disputes[disputeId];
        require(d.state == DisputeState.Active, "not active");
        require(block.timestamp < d.deadline, "voting ended");

        // World ID verification placeholder
        require(_verifyWorldId(), "World ID verification failed");

        if (support) {
            d.votesFor++;
        } else {
            d.votesAgainst++;
        }

        emit VoteCast(disputeId, support);
    }

    function executeDispute(uint256 disputeId) external {
        Dispute storage d = disputes[disputeId];
        require(d.state == DisputeState.Active, "not active");
        require(block.timestamp >= d.deadline, "voting not ended");

        if (d.votesFor > d.votesAgainst) {
            d.state = DisputeState.Approved;
            // Refund deposit to initiator
            cornToken.safeTransfer(d.initiator, d.deposit);
        } else {
            d.state = DisputeState.Rejected;
            // Deposit goes to contract as penalty
        }

        emit DisputeExecuted(disputeId, d.state);
    }

    function setDisputeDeposit(uint256 _deposit) external onlyOwner {
        disputeDeposit = _deposit;
    }

    function setVotingPeriod(uint256 _period) external onlyOwner {
        votingPeriod = _period;
    }

    function _verifyWorldId() internal view returns (bool) {
        // TODO: integrate World ID IdentityManager
        return true;
    }

    /// @notice Allows owner to withdraw disputed deposits
    function withdrawFees() external onlyOwner {
        uint256 balance = cornToken.balanceOf(address(this));
        uint256 activeDeposits = _totalActiveDeposits();
        if (balance > activeDeposits) {
            cornToken.safeTransfer(owner(), balance - activeDeposits);
        }
    }

    function _totalActiveDeposits() internal view returns (uint256) {
        uint256 total;
        for (uint256 i = 1; i <= disputeCount; i++) {
            if (disputes[i].state == DisputeState.Active) {
                total += disputes[i].deposit;
            }
        }
        return total;
    }
}
```

**Step 4: Run test to verify it passes**

Run: `forge test --match-contract HumanHouseTest -vvv`
Expected: PASS

**Step 5: Commit**

```bash
git add src/HumanHouse.sol test/HumanHouse.t.sol
git commit -m "feat: add HumanHouse dispute resolution contract"
```

---

### Task 4: TokenHouse (OZ Governor)

**Files:**
- Create: `src/TokenHouse.sol`

Since TokenHouse is a standard OZ Governor, this is a thin wrapper. The real complexity is in configuration.

```solidity
// src/TokenHouse.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";

contract TokenHouse is
    Governor,
    GovernorSettings,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    constructor(IVotes _govCORN, TimelockController _timelock)
        Governor("TokenHouse")
        GovernorSettings(0, 0, 0)   // delay, votingPeriod, proposalThreshold — set post-deploy
        GovernorVotes(_govCORN)
        GovernorVotesQuorumFraction(4)  // 4% quorum
        GovernorTimelockControl(_timelock)
    {}

    function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {
        return GovernorSettings.votingDelay();
    }

    function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {
        return GovernorSettings.votingPeriod();
    }

    function quorum(uint256 blockNumber)
        public view override(Governor, GovernorVotesQuorumFraction) returns (uint256)
    {
        return GovernorVotesQuorumFraction.quorum(blockNumber);
    }

    function state(uint256 proposalId)
        public view override(Governor, GovernorTimelockControl) returns (ProposalState)
    {
        return GovernorTimelockControl.state(proposalId);
    }

    function proposalNeedsQueuing(uint256 proposalId)
        public view override(Governor, GovernorTimelockControl) returns (bool)
    {
        return GovernorTimelockControl.proposalNeedsQueuing(proposalId);
    }

    function _queueOperations(uint256 proposalId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        internal override(Governor, GovernorTimelockControl) returns (uint48)
    {
        return GovernorTimelockControl._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executeOperations(uint256 proposalId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        internal override(Governor, GovernorTimelockControl)
    {
        GovernorTimelockControl._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancelOperations(uint256 proposalId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        internal override(Governor, GovernorTimelockControl) returns (bool)
    {
        return GovernorTimelockControl._cancelOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal view override(Governor, GovernorTimelockControl) returns (address)
    {
        return GovernorTimelockControl._executor();
    }
}
```

**Verification:** Compile only — no separate test needed as OZ Governor is battle-tested.

Run: `forge build`
Expected: No errors

**Commit:**

```bash
git add src/TokenHouse.sol
git commit -m "feat: add TokenHouse OZ Governor wrapper"
```

---

### Task 5: Integration — Full Governance Flow Test

**Files:**
- Create: `test/integration/GovernanceIntegration.t.sol`

**Step 1: Write integration test**

```solidity
// test/integration/GovernanceIntegration.t.sol
pragma solidity ^0.8.26;
import "forge-std/Test.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "../../src/CornToken.sol";
import "../../src/GovCrownToken.sol";
import "../../src/PredictionMarket.sol";
import "../../src/TokenHouse.sol";
import "../../src/HumanHouse.sol";

contract GovernanceIntegrationTest is Test {
    CornToken corn;
    GovCrownToken govCorn;
    PredictionMarket market;
    TimelockController timelock;
    TokenHouse tokenHouse;
    HumanHouse humanHouse;

    address admin = address(0x100);
    address alice = address(0x1);
    address feeCollector = address(0x99);

    function setUp() public {
        // Deploy CORN
        vm.startPrank(admin);
        corn = new CornToken();
        // Transfer some CORN to alice
        corn.transfer(alice, 100_000e18);

        // Deploy GovCORN
        govCorn = new GovCrownToken(address(corn));

        // Deploy Timelock
        timelock = new TimelockController(
            2 days,
            new address[](0),
            new address[](0),
            admin
        );

        // Deploy PredictionMarket proxy
        PredictionMarket impl = new PredictionMarket();
        bytes memory initData = abi.encodeWithSelector(
            PredictionMarket.initialize.selector,
            address(corn), feeCollector, admin
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        market = PredictionMarket(address(proxy));

        // Deploy TokenHouse
        tokenHouse = new TokenHouse(IVotes(address(govCorn)), timelock);

        // Deploy HumanHouse
        humanHouse = new HumanHouse(address(corn), address(market), 1000e18);

        // Setup Timelock roles
        address[] memory proposers = new address[](2);
        proposers[0] = address(tokenHouse);
        proposers[1] = address(humanHouse);
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(tokenHouse));
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(humanHouse));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.revokeRole(timelock.TIMELOCK_ADMIN_ROLE(), admin);
        timelock.grantRole(timelock.TIMELOCK_ADMIN_ROLE(), address(timelock));

        // Transfer market ownership to timelock
        market.transferOwnership(address(timelock));
        vm.stopPrank();
    }

    function test_Timelock_IsPredictionMarketOwner() public view {
        assertEq(market.owner(), address(timelock));
    }

    function test_CornToken_OwnershipTransferred() public view {
        assertEq(corn.owner(), address(timelock));
    }

    function test_TimelockProposers() public view {
        assertTrue(timelock.hasRole(timelock.PROPOSER_ROLE(), address(tokenHouse)));
        assertTrue(timelock.hasRole(timelock.PROPOSER_ROLE(), address(humanHouse)));
    }

    function test_GovCorn_WrapsCorn() public {
        vm.startPrank(alice);
        corn.approve(address(govCorn), 10_000e18);
        govCorn.depositFor(alice, 10_000e18);
        assertEq(govCorn.balanceOf(alice), 10_000e18);
        assertEq(govCorn.decimals(), corn.decimals());
        vm.stopPrank();
    }
}
```

**Step 2: Run tests**

Run: `forge test --match-contract GovernanceIntegrationTest -vvv`
Expected: ALL tests PASS

**Step 3: Commit**

```bash
git add test/integration/GovernanceIntegration.t.sol
git commit -m "test: add governance integration test"
```

---

### Task 6: Frontend — Governance Pages

**Files:**
- Modify: `frontend/src/App.tsx`
- Create: `frontend/src/pages/Governance.tsx`
- Create: `frontend/src/pages/Delegate.tsx`
- Modify: `frontend/src/hooks/useToken.ts`
- Create: `frontend/src/hooks/useGovernance.ts`
- Modify: `frontend/src/contracts/abi.ts`
- Modify: `frontend/src/contracts/addresses.ts`

**Step 1: Add governance ABIs**

Add GovCrownToken ABI, TokenHouse ABI, and HumanHouse ABI to `frontend/src/contracts/abi.ts`.

**Step 2: Add governance hooks**

Create `frontend/src/hooks/useGovernance.ts` with:
- `useGovCornBalance()` — govCORN balance
- `useDepositGovCorn()` — wrap CORN → govCORN
- `useWithdrawGovCorn()` — unwrap govCORN → CORN
- `useDelegate()` — delegate voting power
- `useGetVotes()` — query voting power
- `useProposals()` — list active proposals
- `useCastVote()` — vote on proposal

**Step 3: Add Delegate page**

`frontend/src/pages/Delegate.tsx`:
- Show CORN balance + govCORN balance
- Deposit / Withdraw form
- Delegate to self or to another address
- Show current delegation and voting power

**Step 4: Add Governance page**

`frontend/src/pages/Governance.tsx`:
- List active proposals from TokenHouse
- Proposal detail: for/against/abstain votes, status, time remaining
- Vote button (if user has voting power)
- Link to create proposal (via Tally or custom UI)

**Step 5: Wire routing in App.tsx**

Add routes for `/delegate` and `/governance`.

**Step 6: Build check**

Run: `cd frontend && npm run build`
Expected: No errors

**Step 7: Commit**

```bash
git add frontend/src/pages/Governance.tsx frontend/src/pages/Delegate.tsx frontend/src/hooks/useGovernance.ts frontend/src/App.tsx frontend/src/contracts/abi.ts frontend/src/contracts/addresses.ts
git commit -m "feat: add governance frontend pages"
```

---

### Task 7: Deployment Scripts

**Files:**
- Create: `script/DeployPhase2.s.sol`
- Create: `script/DeployPhase3.s.sol`

**Step 1: Phase 2 deployment script**

Deploys GovCrownToken, TimelockController, transfers ownership.

**Step 2: Phase 3 deployment script**

Deploys TokenHouse, HumanHouse, configures Timelock proposers.

**Step 3: Commit**

```bash
git add script/DeployPhase2.s.sol script/DeployPhase3.s.sol
git commit -m "feat: add Phase 2/3 deployment scripts"
```

---

### Task 8: World ID Integration (HumanHouse)

**Files:**
- Modify: `src/HumanHouse.sol`
- Create: `src/interfaces/IWorldID.sol`
- Update: `test/HumanHouse.t.sol`

Integrate World ID IdentityManager into HumanHouse:
- Add `IWorldID` interface
- Replace `_verifyWorldId()` placeholder with actual ZKP verification
- Add `root` + `nullifierHash` + `proof` parameters to `vote()` and `raiseDispute()`
- Fork test with World Chain Sepolia

This task depends on World ID contract addresses on World Chain.
