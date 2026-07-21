# World ID Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Integrate World ID v3 ZKP verification into HumanHouse.vote() to enforce one-human-one-vote sybil resistance.

**Architecture:** HumanHouse will call WorldIdRouter.verifyProof() during each vote, using the user's wallet address as signal and a nullifier to prevent double voting per dispute. Tests use a MockWorldIdRouter to bypass real Orb verification.

**Tech Stack:** Solidity 0.8.26, Foundry, OpenZeppelin, World ID v3 (IWorldID interface)

---

### Task 1: IWorldID Interface + ByteHasher Library

**Files:**
- Create: `src/interfaces/IWorldID.sol`
- Create: `src/libraries/ByteHasher.sol`

**Step 1: Create IWorldID interface**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice World ID Router interface for on-chain ZKP verification
interface IWorldID {
    function verifyProof(
        uint256 root,
        uint256 groupId,
        uint256 signalHash,
        uint256 nullifierHash,
        uint256 externalNullifierHash,
        uint256[8] calldata proof
    ) external view;
}
```

**Step 2: Create ByteHasher library**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice Helper to hash bytes to a BN254 field element (fits in 248 bits)
library ByteHasher {
    function hashToField(bytes memory value) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(value))) >> 8;
    }
}
```

**Step 3: Verify compilation**

Run: `.\bin\forge.exe build`
Expected: No errors

**Step 4: Commit**

```bash
git add src/interfaces/IWorldID.sol src/libraries/ByteHasher.sol
git commit -m "feat: add IWorldID interface and ByteHasher library"
```

---

### Task 2: MockWorldIdRouter for Testing

**Files:**
- Create: `test/mocks/MockWorldIdRouter.sol`

**Step 1: Create the mock**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice Mock World ID router that always passes verification.
/// Set `shouldRevert` to true to simulate invalid proofs.
contract MockWorldIdRouter {
    bool public shouldRevert;
    uint256 public lastNullifierHash;
    uint256 public lastSignalHash;

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function verifyProof(
        uint256,
        uint256,
        uint256 signalHash,
        uint256 nullifierHash,
        uint256,
        uint256[8] calldata
    ) external view {
        if (shouldRevert) revert("MockWorldId: invalid proof");
        lastNullifierHash = nullifierHash;
        lastSignalHash = signalHash;
    }
}
```

Note: `lastNullifierHash` and `lastSignalHash` are state writes inside a `view` function. While this is technically a violation of `view`, Foundry tests allow it via state clearing between tests. If the compiler complains, remove the `view` modifier from the mock only (the real IWorldID keeps `view`).

**Step 2: Verify compilation**

Run: `.\bin\forge.exe build`
Expected: No errors

**Step 3: Commit**

```bash
git add test/mocks/MockWorldIdRouter.sol
git commit -m "test: add MockWorldIdRouter for HumanHouse testing"
```

---

### Task 3: Update HumanHouse Contract

**Files:**
- Modify: `src/HumanHouse.sol`

**Step 1: Add imports and update state**

Add at top of file:
```solidity
import "../interfaces/IWorldID.sol";
import "../libraries/ByteHasher.sol";
```

Add new state variables:
```solidity
using ByteHasher for bytes;

IWorldID public immutable worldIdRouter;
uint256 public immutable externalNullifierHash;
uint256 public immutable groupId = 1;

mapping(uint256 => mapping(uint256 => bool)) public nullifierUsed;
```

Remove the old `hasVoted` mapping and `_verifyWorldId()` function.

**Step 2: Update constructor**

```solidity
constructor(
    address _cornToken,
    address _predictionMarket,
    uint256 _disputeDeposit,
    IWorldID _worldIdRouter,
    string memory _appId,
    string memory _actionId
) Ownable(msg.sender) {
    require(_cornToken != address(0), "invalid token");
    require(_predictionMarket != address(0), "invalid market");
    require(address(_worldIdRouter) != address(0), "invalid worldId");
    cornToken = IERC20(_cornToken);
    predictionMarket = _predictionMarket;
    disputeDeposit = _disputeDeposit;
    worldIdRouter = _worldIdRouter;
    externalNullifierHash = abi.encodePacked(
        abi.encodePacked(_appId).hashToField(),
        _actionId
    ).hashToField();
}
```

**Step 3: Update vote() function**

```solidity
function vote(
    uint256 disputeId,
    bool support,
    uint256 root,
    uint256 nullifierHash,
    uint256[8] calldata proof
) external whenNotPaused {
    Dispute storage d = disputes[disputeId];
    require(d.state == DisputeState.Active, "not active");
    require(block.timestamp < d.deadline, "voting ended");
    require(!nullifierUsed[disputeId][nullifierHash], "already voted");

    worldIdRouter.verifyProof(
        root,
        groupId,
        abi.encodePacked(msg.sender).hashToField(),
        nullifierHash,
        externalNullifierHash,
        proof
    );

    nullifierUsed[disputeId][nullifierHash] = true;

    if (support) {
        d.votesFor++;
    } else {
        d.votesAgainst++;
    }

    emit VoteCast(disputeId, support);
}
```

**Step 4: Verify compilation**

Run: `.\bin\forge.exe build`
Expected: No errors (may have lint warnings about custom errors)

**Step 5: Commit**

```bash
git add src/HumanHouse.sol
git commit -m "feat: integrate World ID ZKP verification into HumanHouse.vote()"
```

---

### Task 4: Update HumanHouse Tests

**Files:**
- Modify: `test/HumanHouse.t.sol`

**Step 1: Update setUp to deploy MockWorldIdRouter**

Add to setUp:
```solidity
MockWorldIdRouter mockWorldId = new MockWorldIdRouter();
humanHouse = new HumanHouse(
    address(corn),
    address(market),
    1000e18,
    IWorldID(address(mockWorldId)),
    "app_test",
    "human_house_vote"
);
```

**Step 2: Update all vote() calls**

Every existing `vote(disputeId, support)` call becomes:
```solidity
humanHouse.vote(disputeId, support, 0, uint256(keccak256("n1")), proof);
```

Where `proof` is a dummy `uint256[8]` array:
```solidity
uint256[8] memory proof = [uint256(1), 2, 3, 4, 5, 6, 7, 8];
```

And the nullifierHash must be unique per vote call (use incrementing counter or `keccak256("n1")`, `keccak256("n2")`, etc.).

**Step 3: Add new test for duplicate nullifier**

```solidity
function test_DuplicateNullifierReverts() public {
    market.resolveMarket(1, true);

    vm.startPrank(alice);
    corn.approve(address(humanHouse), 1000e18);
    humanHouse.raiseDispute(1, HumanHouse.DisputeType.OracleResult, "bad oracle");
    vm.stopPrank();

    uint256[8] memory proof = [uint256(1), 2, 3, 4, 5, 6, 7, 8];
    uint256 nullifier = uint256(keccak256("unique_nullifier"));

    vm.prank(alice);
    humanHouse.vote(1, true, 0, nullifier, proof);

    vm.prank(bob);
    vm.expectRevert("already voted");
    humanHouse.vote(1, true, 0, nullifier, proof);
}
```

**Step 4: Add new test for invalid proof**

```solidity
function test_InvalidProofReverts() public {
    market.resolveMarket(1, true);

    vm.startPrank(alice);
    corn.approve(address(humanHouse), 1000e18);
    humanHouse.raiseDispute(1, HumanHouse.DisputeType.OracleResult, "bad oracle");
    vm.stopPrank();

    mockWorldId.setShouldRevert(true);

    uint256[8] memory proof = [uint256(1), 2, 3, 4, 5, 6, 7, 8];
    vm.prank(alice);
    vm.expectRevert("MockWorldId: invalid proof");
    humanHouse.vote(1, true, 0, uint256(keccak256("n1")), proof);
}
```

**Step 5: Run tests**

Run: `.\bin\forge.exe test --match-contract HumanHouseTest -vvv`
Expected: ALL tests PASS

**Step 6: Commit**

```bash
git add test/HumanHouse.t.sol
git commit -m "test: update HumanHouse tests for World ID integration"
```

---

### Task 5: Update DeployPhase3 Script

**Files:**
- Modify: `script/DeployPhase3.s.sol`

**Step 1: Add World ID params to deploy script**

```solidity
address worldIdRouter = vm.envAddress("WORLD_ID_ROUTER_ADDRESS");
string memory appId = vm.envString("WORLD_ID_APP_ID");
string memory actionId = vm.envOr("WORLD_ID_ACTION_ID", string("human_house_vote"));

HumanHouse humanHouse = new HumanHouse(
    cornToken, marketProxy, disputeDeposit,
    IWorldID(worldIdRouter), appId, actionId
);
```

Add imports:
```solidity
import "../interfaces/IWorldID.sol";
```

**Step 2: Verify compilation**

Run: `.\bin\forge.exe build`
Expected: No errors

**Step 3: Commit**

```bash
git add script/DeployPhase3.s.sol
git commit -m "feat: update DeployPhase3 with World ID router params"
```

---

### Task 6: Update Frontend ABIs

**Files:**
- Modify: `frontend/src/contracts/abi.ts`

**Step 1: Add HumanHouse ABI**

```typescript
export const HUMAN_HOUSE_ADDRESS = '0x...'

export const humanHouseABI = [
  'function raiseDispute(uint256 marketId, uint8 disputeType, string reason)',
  'function vote(uint256 disputeId, bool support, uint256 root, uint256 nullifierHash, uint256[8] proof)',
  'function executeDispute(uint256 disputeId)',
  'function disputeDeposit() view returns (uint256)',
  'function votingPeriod() view returns (uint256)',
  'function disputes(uint256 id) view returns (uint256 marketId, uint8 disputeType, uint8 state, address initiator, uint256 deposit, uint256 deadline, string reason, uint256 votesFor, uint256 votesAgainst)',
  'function disputeCount() view returns (uint256)',
  'event DisputeCreated(uint256 indexed disputeId, uint256 indexed marketId, uint8 disputeType, string reason)',
  'event VoteCast(uint256 indexed disputeId, bool support)',
  'event DisputeExecuted(uint256 indexed disputeId, uint8 outcome, uint256 votesFor, uint256 votesAgainst)',
] as const
```

**Step 2: Commit**

```bash
git add frontend/src/contracts/abi.ts
git commit -m "feat: add HumanHouse ABI to frontend"
```
