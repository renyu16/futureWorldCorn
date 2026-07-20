# Governance Frontend + Deployment Scripts Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add frontend governance pages (Delegate + Governance) and Foundry deployment scripts (Phase 2/3).

**Architecture:** Extend existing React/wagmi frontend with manual routing, add GovCORN wrapping/delegation and TokenHouse proposal voting UIs. Event logs via viem getLogs.

**Tech Stack:** React 18, TypeScript, wagmi 2, viem 2, Vite, RainbowKit, Solidity 0.8.26, Foundry

---

### Task A: ABIs + Contract Addresses

**Files:**
- Modify: `frontend/src/contracts/abi.ts`

**Step 1: Add GovCrownToken ABI + address**

Append to `abi.ts`:
```typescript
export const GOV_CORN_TOKEN_ADDRESS = '0x...' as const

export const govCrownTokenABI = [
  'function depositFor(address account, uint256 amount)',
  'function withdrawTo(address account, uint256 amount)',
  'function delegate(address delegatee)',
  'function getVotes(address account) view returns (uint256)',
  'function balanceOf(address account) view returns (uint256)',
  'function totalSupply() view returns (uint256)',
  'function allowance(address owner, address spender) view returns (uint256)',
  'function approve(address spender, uint256 amount) returns (bool)',
  'function transferFrom(address from, address to, uint256 amount) returns (bool)',
  'function decimals() view returns (uint8)',
  'event Transfer(address indexed from, address indexed to, uint256 value)',
] as const
```

**Step 2: Add TokenHouse ABI + address**

```typescript
export const TOKEN_HOUSE_ADDRESS = '0x...' as const

export const tokenHouseABI = [
  'function state(uint256 proposalId) view returns (uint8)',
  'function proposalProposer(uint256 proposalId) view returns (address)',
  'function proposalDeadline(uint256 proposalId) view returns (uint256)',
  'function proposalSnapshot(uint256 proposalId) view returns (uint256)',
  'function proposalVotes(uint256 proposalId) view returns (uint256 against, uint256 for, uint256 abstain)',
  'function castVote(uint256 proposalId, uint8 support) returns (uint256)',
  'function hashProposal(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) view returns (uint256)',
  'event ProposalCreated(uint256 proposalId, address proposer, address[] targets, uint256[] values, string[] signatures, bytes[] calldatas, uint256 voteStart, uint256 voteEnd, string description)',
] as const
```

**Step 3: Commit**

```bash
git add frontend/src/contracts/abi.ts
git commit -m "feat: add GovCrownToken and TokenHouse ABIs"
```

---

### Task B: useGovernance Hook

**Files:**
- Create: `frontend/src/hooks/useGovernance.ts`

**Step 1: Write the hook**

```typescript
import { useReadContract, useWriteContract, usePublicClient } from 'wagmi'
import { useCallback, useEffect, useState } from 'react'
import { TOKEN_HOUSE_ADDRESS, tokenHouseABI } from '../contracts/abi'

export type ProposalState = 'Pending' | 'Active' | 'Canceled' | 'Defeated' | 'Succeeded' | 'Queued' | 'Expired' | 'Executed'

const STATE_NAMES: Record<number, ProposalState> = {
  0: 'Pending', 1: 'Active', 2: 'Canceled', 3: 'Defeated',
  4: 'Succeeded', 5: 'Queued', 6: 'Expired', 7: 'Executed',
}

export interface Proposal {
  id: bigint
  proposer: string
  description: string
  voteStart: bigint
  voteEnd: bigint
}

export function useProposals() {
  const publicClient = usePublicClient()
  const [proposals, setProposals] = useState<Proposal[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!publicClient) return
    setLoading(true)
    publicClient.getLogs({
      address: TOKEN_HOUSE_ADDRESS,
      event: {
        type: 'event',
        name: 'ProposalCreated',
        inputs: [
          { type: 'uint256', name: 'proposalId', indexed: false },
          { type: 'address', name: 'proposer', indexed: false },
          { type: 'address[]', name: 'targets', indexed: false },
          { type: 'uint256[]', name: 'values', indexed: false },
          { type: 'string[]', name: 'signatures', indexed: false },
          { type: 'bytes[]', name: 'calldatas', indexed: false },
          { type: 'uint256', name: 'voteStart', indexed: false },
          { type: 'uint256', name: 'voteEnd', indexed: false },
          { type: 'string', name: 'description', indexed: false },
        ],
      },
      fromBlock: 0n,
      toBlock: 'latest',
    }).then(logs => {
      setProposals(logs.map(log => ({
        id: (log as any).args.proposalId as bigint,
        proposer: (log as any).args.proposer as string,
        description: (log as any).args.description as string,
        voteStart: (log as any).args.voteStart as bigint,
        voteEnd: (log as any).args.voteEnd as bigint,
      })).reverse())
      setLoading(false)
    }).catch(() => setLoading(false))
  }, [publicClient])

  return { proposals, loading }
}

export function useProposalState(proposalId: bigint | undefined) {
  const { data } = useReadContract({
    address: TOKEN_HOUSE_ADDRESS,
    abi: tokenHouseABI,
    functionName: 'state',
    args: proposalId !== undefined ? [proposalId] : undefined,
    query: { enabled: proposalId !== undefined },
  })
  return { state: data !== undefined ? STATE_NAMES[Number(data)] : undefined, rawState: data }
}

export function useProposalVotes(proposalId: bigint | undefined) {
  const { data } = useReadContract({
    address: TOKEN_HOUSE_ADDRESS,
    abi: tokenHouseABI,
    functionName: 'proposalVotes',
    args: proposalId !== undefined ? [proposalId] : undefined,
    query: { enabled: proposalId !== undefined },
  })
  if (!data) return { against: undefined, for: undefined, abstain: undefined }
  const [against, forVotes, abstain] = data
  return { against, for: forVotes, abstain }
}

export function useProposalProposer(proposalId: bigint | undefined) {
  const { data } = useReadContract({
    address: TOKEN_HOUSE_ADDRESS,
    abi: tokenHouseABI,
    functionName: 'proposalProposer',
    args: proposalId !== undefined ? [proposalId] : undefined,
    query: { enabled: proposalId !== undefined },
  })
  return { proposer: data as string | undefined }
}

export function useProposalDeadline(proposalId: bigint | undefined) {
  const { data } = useReadContract({
    address: TOKEN_HOUSE_ADDRESS,
    abi: tokenHouseABI,
    functionName: 'proposalDeadline',
    args: proposalId !== undefined ? [proposalId] : undefined,
    query: { enabled: proposalId !== undefined },
  })
  return { deadline: data as bigint | undefined }
}

export function useProposalSnapshot(proposalId: bigint | undefined) {
  const { data } = useReadContract({
    address: TOKEN_HOUSE_ADDRESS,
    abi: tokenHouseABI,
    functionName: 'proposalSnapshot',
    args: proposalId !== undefined ? [proposalId] : undefined,
    query: { enabled: proposalId !== undefined },
  })
  return { snapshot: data as bigint | undefined }
}

export function useCastVote() {
  const { writeContract } = useWriteContract()
  const castVote = useCallback((proposalId: bigint, support: number) => {
    writeContract({
      address: TOKEN_HOUSE_ADDRESS,
      abi: tokenHouseABI,
      functionName: 'castVote',
      args: [proposalId, support],
    })
  }, [writeContract])
  return { castVote }
}
```

**Step 2: Commit**

```bash
git add frontend/src/hooks/useGovernance.ts
git commit -m "feat: add useGovernance hooks for proposals and voting"
```

---

### Task C: Delegate Page

**Files:**
- Create: `frontend/src/pages/Delegate.tsx`

**Step 1: Write the page**

Key UI elements:
- CORN balance display
- govCORN balance display
- Voting power (getVotes) display
- Deposit section: amount input + "Approve" (if needed) + "Deposit" button
- Withdraw section: amount input + "Withdraw" button
- Delegate section: current delegatee display + address input + "Delegate" button

All read queries use wagmi, writes use useWriteContract.

```tsx
import { useState } from 'react'
import { useAccount } from 'wagmi'
import { useReadContract, useWriteContract } from 'wagmi'
import { parseEther, formatEther } from 'viem'
import {
  CORN_TOKEN_ADDRESS, cornTokenABI,
  GOV_CORN_TOKEN_ADDRESS, govCrownTokenABI,
} from '../contracts/abi'

export default function Delegate() {
  const { address, isConnected } = useAccount()
  const [depositAmount, setDepositAmount] = useState('')
  const [withdrawAmount, setWithdrawAmount] = useState('')
  const [delegatee, setDelegatee] = useState('')

  const { data: cornBalance } = useReadContract({
    address: CORN_TOKEN_ADDRESS, abi: cornTokenABI, functionName: 'balanceOf',
    args: address ? [address] : undefined, query: { enabled: !!address },
  })
  const { data: govCornBalance } = useReadContract({
    address: GOV_CORN_TOKEN_ADDRESS, abi: govCrownTokenABI, functionName: 'balanceOf',
    args: address ? [address] : undefined, query: { enabled: !!address },
  })
  const { data: votes } = useReadContract({
    address: GOV_CORN_TOKEN_ADDRESS, abi: govCrownTokenABI, functionName: 'getVotes',
    args: address ? [address] : undefined, query: { enabled: !!address },
  })
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: CORN_TOKEN_ADDRESS, abi: cornTokenABI, functionName: 'allowance',
    args: address ? [address, GOV_CORN_TOKEN_ADDRESS] : undefined, query: { enabled: !!address },
  })

  const { writeContract } = useWriteContract()

  const amount = parseEther(depositAmount || '0')
  const needsApprove = allowance !== undefined && amount > 0 && amount > (allowance as bigint)

  return (
    <div>
      <h2>Delegate</h2>
      {!isConnected ? <p>Connect wallet</p> : (
        <>
          <p>CORN: {cornBalance ? formatEther(cornBalance as bigint) : '—'}</p>
          <p>govCORN: {govCornBalance ? formatEther(govCornBalance as bigint) : '—'}</p>
          <p>Voting Power: {votes ? formatEther(votes as bigint) : '—'}</p>

          <h3>Deposit CORN → govCORN</h3>
          <input value={depositAmount} onChange={e => setDepositAmount(e.target.value)} placeholder="Amount" />
          <button onClick={() => {
            writeContract({
              address: CORN_TOKEN_ADDRESS, abi: cornTokenABI,
              functionName: 'approve', args: [GOV_CORN_TOKEN_ADDRESS, amount],
            }, { onSuccess: () => refetchAllowance() })
          }} disabled={!needsApprove}>Approve</button>
          <button onClick={() => {
            writeContract({
              address: GOV_CORN_TOKEN_ADDRESS, abi: govCrownTokenABI,
              functionName: 'depositFor', args: [address, amount],
            })
          }} disabled={needsApprove || amount === 0n}>Deposit</button>

          <h3>Withdraw govCORN → CORN</h3>
          <input value={withdrawAmount} onChange={e => setWithdrawAmount(e.target.value)} placeholder="Amount" />
          <button onClick={() => {
            writeContract({
              address: GOV_CORN_TOKEN_ADDRESS, abi: govCrownTokenABI,
              functionName: 'withdrawTo', args: [address, parseEther(withdrawAmount || '0')],
            })
          }}>Withdraw</button>

          <h3>Delegate Voting Power</h3>
          <input value={delegatee} onChange={e => setDelegatee(e.target.value)} placeholder="Delegate address" />
          <button onClick={() => {
            writeContract({
              address: GOV_CORN_TOKEN_ADDRESS, abi: govCrownTokenABI,
              functionName: 'delegate', args: [delegatee as `0x${string}`],
            })
          }}>Delegate</button>
        </>
      )}
    </div>
  )
}
```

**Step 2: Commit**

```bash
git add frontend/src/pages/Delegate.tsx
git commit -m "feat: add Delegate page for govCORN wrapping and delegation"
```

---

### Task D: Governance Page

**Files:**
- Create: `frontend/src/pages/Governance.tsx`

**Step 1: Write the page**

Key UI:
- On mount, fetch proposals via useProposals()
- Show list of proposals (id, description preview, state badge)
- Click to expand detail: for/against/abstain, proposer, deadline, snapshot
- If Active and user has voting power: show For / Against / Abstain buttons
- After voting, show confirmation

```tsx
import { useState } from 'react'
import { useAccount } from 'wagmi'
import { formatEther } from 'viem'
import { useProposals, useProposalState, useProposalVotes, useProposalProposer, useProposalDeadline, useProposalSnapshot, useCastVote } from '../hooks/useGovernance'
import { useReadContract } from 'wagmi'
import { GOV_CORN_TOKEN_ADDRESS, govCrownTokenABI } from '../contracts/abi'

const STATE_COLORS: Record<string, string> = {
  Pending: '#f0ad4e', Active: '#5bc0de', Succeeded: '#5cb85c',
  Queued: '#5cb85c', Executed: '#5cb85c', Defeated: '#d9534f',
  Canceled: '#777', Expired: '#777',
}

function ProposalDetail({ id, onBack }: { id: bigint; onBack: () => void }) {
  const { state } = useProposalState(id)
  const { against, for: forVotes, abstain } = useProposalVotes(id)
  const { proposer } = useProposalProposer(id)
  const { deadline } = useProposalDeadline(id)
  const { snapshot } = useProposalSnapshot(id)
  const { castVote } = useCastVote()
  const { address } = useAccount()

  const { data: userVotes } = useReadContract({
    address: GOV_CORN_TOKEN_ADDRESS, abi: govCrownTokenABI, functionName: 'getVotes',
    args: address ? [address] : undefined, query: { enabled: !!address },
  })

  return (
    <div>
      <button onClick={onBack}>← Back</button>
      <h3>Proposal #{id.toString()}</h3>
      <p>Status: <span style={{ color: STATE_COLORS[state || ''] }}>{state || '—'}</span></p>
      <p>Proposer: {proposer || '—'}</p>
      <p>Snapshot Block: {snapshot?.toString() || '—'}</p>
      <p>Deadline Block: {deadline?.toString() || '—'}</p>
      <p>For: {forVotes !== undefined ? formatEther(forVotes) : '—'} govCORN</p>
      <p>Against: {against !== undefined ? formatEther(against) : '—'} govCORN</p>
      <p>Abstain: {abstain !== undefined ? formatEther(abstain) : '—'} govCORN</p>

      {state === 'Active' && address && (
        <div>
          <p>Your voting power: {userVotes ? formatEther(userVotes as bigint) : '0'} govCORN</p>
          {userVotes && (userVotes as bigint) > 0n && (
            <div>
              <button onClick={() => castVote(id, 1)}>For</button>
              <button onClick={() => castVote(id, 0)}>Against</button>
              <button onClick={() => castVote(id, 2)}>Abstain</button>
            </div>
          )}
        </div>
      )}
    </div>
  )
}

export default function Governance() {
  const { proposals, loading } = useProposals()
  const [selectedId, setSelectedId] = useState<bigint | null>(null)
  const [expandedDescriptions, setExpandedDescriptions] = useState<Set<string>>(new Set())

  if (selectedId !== null) {
    return <ProposalDetail id={selectedId} onBack={() => setSelectedId(null)} />
  }

  return (
    <div>
      <h2>Governance</h2>
      {loading ? <p>Loading proposals...</p> : proposals.length === 0 ? <p>No proposals yet.</p> : (
        <table>
          <thead><tr><th>ID</th><th>Description</th><th>Status</th><th>Action</th></tr></thead>
          <tbody>
            {proposals.map(p => (
              <ProposalRow key={p.id.toString()} proposal={p} onSelect={() => setSelectedId(p.id)} />
            ))}
          </tbody>
        </table>
      )}
    </div>
  )
}

function ProposalRow({ proposal: p, onSelect }: { proposal: { id: bigint; description: string }; onSelect: () => void }) {
  const { state } = useProposalState(p.id)
  const desc = p.description.length > 80 ? p.description.slice(0, 80) + '…' : p.description
  return (
    <tr>
      <td>{p.id.toString()}</td>
      <td>{desc}</td>
      <td><span style={{ color: STATE_COLORS[state || ''] }}>{state || '—'}</span></td>
      <td><button onClick={onSelect}>View</button></td>
    </tr>
  )
}
```

**Step 2: Commit**

```bash
git add frontend/src/pages/Governance.tsx
git commit -m "feat: add Governance page with proposal list and voting"
```

---

### Task E: Wire Up App.tsx

**Files:**
- Modify: `frontend/src/App.tsx`

**Step 1: Add nav buttons and page routing**

Add `'governance'` and `'delegate'` to page state type. Add nav buttons between "Portfolio" and `<WalletConnect />`. Render `Governance` and `Delegate` components when page matches.

**Step 2: Commit**

```bash
git add frontend/src/App.tsx
git commit -m "feat: wire governance and delegate pages into App"
```

---

### Task F: DeployPhase2 Script

**Files:**
- Create: `script/DeployPhase2.s.sol`

**Step 1: Write deploy script**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "forge-std/Script.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "../src/GovCrownToken.sol";
import "../src/CornToken.sol";
import "../src/PredictionMarket.sol";

contract DeployPhase2 is Script {
    function run() external {
        address deployer = vm.addr(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        address cornToken = vm.envAddress("CORN_TOKEN_ADDRESS");
        address marketProxy = vm.envAddress("MARKET_PROXY_ADDRESS");
        address safeAddress = vm.envAddress("SAFE_ADDRESS");
        uint256 minDelay = vm.envOr("TIMELOCK_DELAY", uint256(2 days));

        vm.startBroadcast();

        GovCrownToken govCorn = new GovCrownToken(IERC20(cornToken));

        address[] memory proposers = new address[](1);
        proposers[0] = safeAddress;
        TimelockController timelock = new TimelockController(
            minDelay, proposers, new address[](0), deployer
        );
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        PredictionMarket market = PredictionMarket(marketProxy);
        market.transferOwnership(address(timelock));

        CornToken token = CornToken(payable(cornToken));
        token.transferOwnership(address(timelock));

        vm.stopBroadcast();
    }
}
```

**Step 2: Commit**

```bash
git add script/DeployPhase2.s.sol
git commit -m "feat: add Phase 2 deployment script"
```

---

### Task G: DeployPhase3 Script

**Files:**
- Create: `script/DeployPhase3.s.sol`

**Step 1: Write deploy script**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "forge-std/Script.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "../src/TokenHouse.sol";
import "../src/HumanHouse.sol";

contract DeployPhase3 is Script {
    function run() external {
        address deployer = vm.addr(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        address govCorn = vm.envAddress("GOV_CORN_ADDRESS");
        address timelockAddr = vm.envAddress("TIMELOCK_ADDRESS");
        address cornToken = vm.envAddress("CORN_TOKEN_ADDRESS");
        address marketProxy = vm.envAddress("MARKET_PROXY_ADDRESS");
        uint256 disputeDeposit = vm.envOr("DISPUTE_DEPOSIT", uint256(1000e18));

        vm.startBroadcast();

        TimelockController timelock = TimelockController(payable(timelockAddr));

        TokenHouse tokenHouse = new TokenHouse(IVotes(govCorn), timelock);
        HumanHouse humanHouse = new HumanHouse(cornToken, marketProxy, disputeDeposit);

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(tokenHouse));
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(humanHouse));

        vm.stopBroadcast();
    }
}
```

**Step 2: Commit**

```bash
git add script/DeployPhase3.s.sol
git commit -m "feat: add Phase 3 deployment script"
```
