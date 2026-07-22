# HumanHouse Frontend Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a complete HumanHouse dispute management frontend page with event-log-based listing, raise dispute, World ID mock voting, and dispute execution.

**Architecture:** Follow existing Governance.tsx patterns — manual useState routing, wagmi hooks, event-log-based data fetching, inline styles. Add `useHumanHouse` hook for contract interactions and `HumanHouse.tsx` page component.

**Tech Stack:** React 18, wagmi v2, viem, RainbowKit, TypeScript, Vite

---

### Task 1: useHumanHouse Hook

**Files:**
- Create: `frontend/src/hooks/useHumanHouse.ts`

**Step 1: Create the hook file**

Create `frontend/src/hooks/useHumanHouse.ts` with the following exports:

```typescript
import { useReadContract, useWriteContract, usePublicClient } from 'wagmi'
import { HUMAN_HOUSE_ADDRESS, humanHouseABI } from '../contracts/abi'

// Read hooks
export function useDisputeDeposit() {
  return useReadContract({
    address: HUMAN_HOUSE_ADDRESS,
    abi: humanHouseABI,
    functionName: 'disputeDeposit',
  })
}

export function useVotingPeriod() {
  return useReadContract({
    address: HUMAN_HOUSE_ADDRESS,
    abi: humanHouseABI,
    functionName: 'votingPeriod',
  })
}

export function useDisputeCount() {
  return useReadContract({
    address: HUMAN_HOUSE_ADDRESS,
    abi: humanHouseABI,
    functionName: 'disputeCount',
  })
}

export function useDispute(disputeId: bigint | undefined) {
  return useReadContract({
    address: HUMAN_HOUSE_ADDRESS,
    abi: humanHouseABI,
    functionName: 'disputes',
    args: disputeId !== undefined ? [disputeId] : undefined,
  })
}

// Write hooks
export function useRaiseDispute() {
  return useWriteContract()
}

export function useVote() {
  return useWriteContract()
}

export function useExecuteDispute() {
  return useWriteContract()
}

// Event log fetcher
export async function fetchDisputeCreatedLogs(publicClient: any) {
  return publicClient.getLogs({
    address: HUMAN_HOUSE_ADDRESS,
    event: {
      type: 'event',
      name: 'DisputeCreated',
      inputs: [
        { type: 'uint256', name: 'disputeId', indexed: true },
        { type: 'uint256', name: 'marketId', indexed: true },
        { type: 'uint8', name: 'disputeType' },
        { type: 'string', name: 'reason' },
      ],
    },
    fromBlock: 0n,
    toBlock: 'latest',
  })
}
```

**Step 2: Verify TypeScript compiles**

Run: `cd frontend && npx tsc --noEmit`
Expected: No errors

**Step 3: Commit**

```bash
git add frontend/src/hooks/useHumanHouse.ts
git commit -m "feat: add useHumanHouse hook"
```

---

### Task 2: HumanHouse Page — Dispute List

**Files:**
- Create: `frontend/src/pages/HumanHouse.tsx`

**Step 1: Create the page with dispute list**

Create `frontend/src/pages/HumanHouse.tsx`:

```tsx
import { useEffect, useState } from 'react'
import { useAccount, usePublicClient } from 'wagmi'
import { formatEther } from 'viem'
import { HUMAN_HOUSE_ADDRESS, humanHouseABI } from '../contracts/abi'
import { useDispute, useDisputeDeposit, useDisputeCount, fetchDisputeCreatedLogs } from '../hooks/useHumanHouse'

const DISPUTE_TYPE: Record<number, string> = { 0: 'Oracle Result', 1: 'Market Content' }
const DISPUTE_STATE: Record<number, string> = { 0: 'Active', 1: 'Approved', 2: 'Rejected' }
const STATE_COLOR: Record<number, string> = { 0: '#5bc0de', 1: '#5cb85c', 2: '#d9534f' }

interface DisputeInfo {
  id: bigint
  marketId: bigint
  disputeType: number
  reason: string
}

function DisputeDetail({ id, onBack }: { id: bigint; onBack: () => void }) {
  const { data: dispute } = useDispute(id)

  if (!dispute) return <p>Loading dispute #{id.toString()}...</p>

  const [marketId, disputeType, state, initiator, deposit, deadline, reason, votesFor, votesAgainst] = dispute as any

  return (
    <div>
      <button onClick={onBack} style={{ marginBottom: 12 }}>&larr; Back</button>
      <h3>Dispute #{id.toString()}</h3>
      <p>Market ID: {marketId.toString()}</p>
      <p>Type: {DISPUTE_TYPE[disputeType] || 'Unknown'}</p>
      <p>State: <span style={{ color: STATE_COLOR[state] }}>{DISPUTE_STATE[state] || 'Unknown'}</span></p>
      <p>Initiator: <code>{initiator}</code></p>
      <p>Deposit: {formatEther(deposit)} CORN</p>
      <p>Deadline: {new Date(Number(deadline) * 1000).toLocaleString()}</p>
      <p>Reason: {reason}</p>
      <p>For: <strong>{formatEther(votesFor)}</strong></p>
      <p>Against: <strong>{formatEther(votesAgainst)}</strong></p>
    </div>
  )
}

export function HumanHouse() {
  const { address } = useAccount()
  const publicClient = usePublicClient()
  const [disputes, setDisputes] = useState<DisputeInfo[]>([])
  const [loading, setLoading] = useState(true)
  const [selectedId, setSelectedId] = useState<bigint | null>(null)

  useEffect(() => {
    if (!publicClient) return
    setLoading(true)
    fetchDisputeCreatedLogs(publicClient).then((logs: any[]) => {
      setDisputes(logs.map(l => ({
        id: l.args.disputeId as bigint,
        marketId: l.args.marketId as bigint,
        disputeType: Number(l.args.disputeType),
        reason: l.args.reason as string,
      })).reverse())
      setLoading(false)
    }).catch(() => setLoading(false))
  }, [publicClient])

  if (selectedId !== null) {
    return <DisputeDetail id={selectedId} onBack={() => setSelectedId(null)} />
  }

  return (
    <div>
      <h2>HumanHouse Disputes</h2>
      {!address ? <p>Connect your wallet to view disputes.</p> : loading ? <p>Loading disputes...</p> : disputes.length === 0 ? <p>No disputes yet.</p> : (
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ textAlign: 'left', borderBottom: '2px solid #ccc' }}>
              <th style={{ padding: 8 }}>ID</th>
              <th style={{ padding: 8 }}>Market</th>
              <th style={{ padding: 8 }}>Type</th>
              <th style={{ padding: 8 }}>Reason</th>
              <th style={{ padding: 8 }}></th>
            </tr>
          </thead>
          <tbody>
            {disputes.map(d => (
              <DisputeRow key={d.id.toString()} dispute={d} onSelect={() => setSelectedId(d.id)} />
            ))}
          </tbody>
        </table>
      )}
    </div>
  )
}

function DisputeRow({ dispute: d, onSelect }: { dispute: DisputeInfo; onSelect: () => void }) {
  return (
    <tr style={{ borderBottom: '1px solid #eee' }}>
      <td style={{ padding: 8 }}>{d.id.toString()}</td>
      <td style={{ padding: 8 }}>{d.marketId.toString()}</td>
      <td style={{ padding: 8 }}>{DISPUTE_TYPE[d.disputeType]}</td>
      <td style={{ padding: 8 }}>{d.reason.length > 60 ? d.reason.slice(0, 60) + '...' : d.reason}</td>
      <td style={{ padding: 8 }}><button onClick={onSelect}>View</button></td>
    </tr>
  )
}
```

**Step 2: Verify TypeScript compiles**

Run: `cd frontend && npx tsc --noEmit`
Expected: No errors

**Step 3: Commit**

```bash
git add frontend/src/pages/HumanHouse.tsx
git commit -m "feat: add HumanHouse page with dispute list"
```

---

### Task 3: Add Navigation to App.tsx

**Files:**
- Modify: `frontend/src/App.tsx`

**Step 1: Import HumanHouse and add nav button**

Add import:
```tsx
import { HumanHouse } from './pages/HumanHouse'
```

Add nav button after governance button:
```tsx
<button onClick={() => setPage('humanhouse')}>Disputes</button>
```

Add page render in main section:
```tsx
{page === 'humanhouse' && <HumanHouse />}
```

**Step 2: Verify TypeScript compiles**

Run: `cd frontend && npx tsc --noEmit`
Expected: No errors

**Step 3: Commit**

```bash
git add frontend/src/App.tsx
git commit -m "feat: add HumanHouse navigation to App.tsx"
```

---

### Task 4: Raise Dispute UI

**Files:**
- Modify: `frontend/src/pages/HumanHouse.tsx`

**Step 1: Add RaiseDispute component**

Add inside `HumanHouse.tsx` before the `HumanHouse` function:

```tsx
function RaiseDispute({ onCreated }: { onCreated: () => void }) {
  const { address } = useAccount()
  const [marketId, setMarketId] = useState('')
  const [disputeType, setDisputeType] = useState('0')
  const [reason, setReason] = useState('')
  const { writeContract } = useRaiseDispute()

  return (
    <div style={{ border: '1px solid #ccc', padding: 12, borderRadius: 6, marginBottom: 16 }}>
      <h3>Raise Dispute</h3>
      <div style={{ marginBottom: 8 }}>
        <label>Market ID: </label>
        <input value={marketId} onChange={e => setMarketId(e.target.value)} placeholder="Market ID" style={{ marginRight: 8 }} />
      </div>
      <div style={{ marginBottom: 8 }}>
        <label>Type: </label>
        <select value={disputeType} onChange={e => setDisputeType(e.target.value)}>
          <option value="0">Oracle Result</option>
          <option value="1">Market Content</option>
        </select>
      </div>
      <div style={{ marginBottom: 8 }}>
        <label>Reason: </label>
        <input value={reason} onChange={e => setReason(e.target.value)} placeholder="Why this result is wrong" style={{ width: 400 }} />
      </div>
      <button
        disabled={!marketId || !reason}
        onClick={() => writeContract({
          address: HUMAN_HOUSE_ADDRESS,
          abi: humanHouseABI,
          functionName: 'raiseDispute',
          args: [BigInt(marketId), Number(disputeType), reason],
        }, { onSuccess: () => { setMarketId(''); setReason(''); onCreated() } })}
      >
        Raise Dispute
      </button>
    </div>
  )
}
```

Add `<RaiseDispute onCreated={() => setLoading(true)} />` inside the `HumanHouse` component, after `<h2>`.

**Step 2: Verify TypeScript compiles**

Run: `cd frontend && npx tsc --noEmit`
Expected: No errors

**Step 3: Commit**

```bash
git add frontend/src/pages/HumanHouse.tsx
git commit -m "feat: add raise dispute UI"
```

---

### Task 5: Dispute Detail with Vote and Execute

**Files:**
- Modify: `frontend/src/pages/HumanHouse.tsx`

**Step 1: Add vote and execute buttons to DisputeDetail**

Update the `DisputeDetail` component to include:
- Mock proof vote buttons (For/Against) when state is Active and not past deadline
- Execute button when state is Active and past deadline

```tsx
function DisputeDetail({ id, onBack }: { id: bigint; onBack: () => void }) {
  const { address } = useAccount()
  const { data: dispute } = useDispute(id)
  const { writeContract: writeVote } = useVote()
  const { writeContract: writeExecute } = useExecuteDispute()

  if (!dispute) return <p>Loading dispute #{id.toString()}...</p>

  const [marketId, disputeType, state, initiator, deposit, deadline, reason, votesFor, votesAgainst] = dispute as any
  const isActive = Number(state) === 0
  const isExpired = Date.now() / 1000 > Number(deadline)

  // Mock proof values for testing
  const mockRoot = 0n
  const mockNullifierHash = 0n
  const mockProof = [0n, 0n, 0n, 0n, 0n, 0n, 0n, 0n] as [bigint, bigint, bigint, bigint, bigint, bigint, bigint, bigint]

  return (
    <div>
      <button onClick={onBack} style={{ marginBottom: 12 }}>&larr; Back</button>
      <h3>Dispute #{id.toString()}</h3>
      <p>Market ID: {marketId.toString()}</p>
      <p>Type: {DISPUTE_TYPE[disputeType] || 'Unknown'}</p>
      <p>State: <span style={{ color: STATE_COLOR[state] }}>{DISPUTE_STATE[state] || 'Unknown'}</span></p>
      <p>Initiator: <code>{initiator}</code></p>
      <p>Deposit: {formatEther(deposit)} CORN</p>
      <p>Deadline: {new Date(Number(deadline) * 1000).toLocaleString()}</p>
      <p>Reason: {reason}</p>
      <p>For: <strong>{formatEther(votesFor)}</strong></p>
      <p>Against: <strong>{formatEther(votesAgainst)}</strong></p>

      {/* Vote section */}
      {isActive && !isExpired && address && (
        <div style={{ marginTop: 16, border: '1px solid #ccc', padding: 12, borderRadius: 6 }}>
          <h4>World ID Verification (Mock)</h4>
          <p style={{ fontSize: 12, color: '#888' }}>Currently using mock proof. Real World ID integration coming soon.</p>
          <button
            onClick={() => writeVote({
              address: HUMAN_HOUSE_ADDRESS,
              abi: humanHouseABI,
              functionName: 'vote',
              args: [id, true, mockRoot, mockNullifierHash, mockProof],
            })}
            style={{ marginRight: 8, background: '#5cb85c', color: '#fff', border: 'none', padding: '8px 16px', borderRadius: 4, cursor: 'pointer' }}
          >
            Vote For
          </button>
          <button
            onClick={() => writeVote({
              address: HUMAN_HOUSE_ADDRESS,
              abi: humanHouseABI,
              functionName: 'vote',
              args: [id, false, mockRoot, mockNullifierHash, mockProof],
            })}
            style={{ background: '#d9534f', color: '#fff', border: 'none', padding: '8px 16px', borderRadius: 4, cursor: 'pointer' }}
          >
            Vote Against
          </button>
        </div>
      )}

      {/* Execute section */}
      {isActive && isExpired && address && (
        <div style={{ marginTop: 16, border: '1px solid #ccc', padding: 12, borderRadius: 6 }}>
          <button
            onClick={() => writeExecute({
              address: HUMAN_HOUSE_ADDRESS,
              abi: humanHouseABI,
              functionName: 'executeDispute',
              args: [id],
            })}
            style={{ background: '#f0ad4e', color: '#fff', border: 'none', padding: '8px 16px', borderRadius: 4, cursor: 'pointer' }}
          >
            Execute Dispute
          </button>
        </div>
      )}
    </div>
  )
}
```

**Step 2: Verify TypeScript compiles**

Run: `cd frontend && npx tsc --noEmit`
Expected: No errors

**Step 3: Commit**

```bash
git add frontend/src/pages/HumanHouse.tsx
git commit -m "feat: add vote and execute dispute UI"
```

---

### Task 6: Approve + Raise Dispute Flow

**Files:**
- Modify: `frontend/src/pages/HumanHouse.tsx`

**Step 1: Add CORN approval step before raiseDispute**

Update `RaiseDispute` component to include approve → raiseDispute flow:

```tsx
function RaiseDispute({ onCreated }: { onCreated: () => void }) {
  const { address } = useAccount()
  const [marketId, setMarketId] = useState('')
  const [disputeType, setDisputeType] = useState('0')
  const [reason, setReason] = useState('')
  const { writeContract } = useRaiseDispute()
  const { writeContract: writeApprove } = useWriteContract()

  const { data: disputeDeposit } = useDisputeDeposit()
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: CORN_TOKEN_ADDRESS,
    abi: cornTokenABI,
    functionName: 'allowance',
    args: address ? [address, HUMAN_HOUSE_ADDRESS] : undefined,
  })

  const needsApprove = disputeDeposit && allowance !== undefined && (disputeDeposit as bigint) > (allowance as bigint)

  return (
    <div style={{ border: '1px solid #ccc', padding: 12, borderRadius: 6, marginBottom: 16 }}>
      <h3>Raise Dispute</h3>
      {disputeDeposit && <p>Required deposit: {formatEther(disputeDeposit as bigint)} CORN</p>}
      <div style={{ marginBottom: 8 }}>
        <label>Market ID: </label>
        <input value={marketId} onChange={e => setMarketId(e.target.value)} placeholder="Market ID" style={{ marginRight: 8 }} />
      </div>
      <div style={{ marginBottom: 8 }}>
        <label>Type: </label>
        <select value={disputeType} onChange={e => setDisputeType(e.target.value)}>
          <option value="0">Oracle Result</option>
          <option value="1">Market Content</option>
        </select>
      </div>
      <div style={{ marginBottom: 8 }}>
        <label>Reason: </label>
        <input value={reason} onChange={e => setReason(e.target.value)} placeholder="Why this result is wrong" style={{ width: 400 }} />
      </div>
      <div>
        {needsApprove && (
          <button
            onClick={() => writeApprove({
              address: CORN_TOKEN_ADDRESS,
              abi: cornTokenABI,
              functionName: 'approve',
              args: [HUMAN_HOUSE_ADDRESS, disputeDeposit as bigint],
            }, { onSuccess: () => refetchAllowance() })}
            style={{ marginRight: 8 }}
          >
            Approve CORN
          </button>
        )}
        <button
          disabled={!marketId || !reason || !!needsApprove}
          onClick={() => writeContract({
            address: HUMAN_HOUSE_ADDRESS,
            abi: humanHouseABI,
            functionName: 'raiseDispute',
            args: [BigInt(marketId), Number(disputeType), reason],
          }, { onSuccess: () => { setMarketId(''); setReason(''); onCreated() } })}
        >
          Raise Dispute
        </button>
      </div>
    </div>
  )
}
```

Add imports for `CORN_TOKEN_ADDRESS`, `cornTokenABI`, `useReadContract`, `useWriteContract`.

**Step 2: Verify TypeScript compiles**

Run: `cd frontend && npx tsc --noEmit`
Expected: No errors

**Step 3: Commit**

```bash
git add frontend/src/pages/HumanHouse.tsx
git commit -m "feat: add approve + raise dispute flow"
```

---

### Task 7: Add Dispute Detail State Display

**Files:**
- Modify: `frontend/src/pages/HumanHouse.tsx`

**Step 1: Show state and deadline in dispute list rows**

Update `DisputeRow` to show state and deadline by fetching each dispute's data:

```tsx
function DisputeRow({ dispute: d, onSelect }: { dispute: DisputeInfo; onSelect: () => void }) {
  const { data: dispute } = useDispute(d.id)
  const state = dispute ? (dispute as any)[2] : undefined
  const deadline = dispute ? (dispute as any)[5] : undefined

  return (
    <tr style={{ borderBottom: '1px solid #eee' }}>
      <td style={{ padding: 8 }}>{d.id.toString()}</td>
      <td style={{ padding: 8 }}>{d.marketId.toString()}</td>
      <td style={{ padding: 8 }}>{DISPUTE_TYPE[d.disputeType]}</td>
      <td style={{ padding: 8 }}>
        <span style={{ color: STATE_COLOR[state] || '#888', fontWeight: 'bold' }}>
          {DISPUTE_STATE[state] || '—'}
        </span>
      </td>
      <td style={{ padding: 8 }}>{deadline ? new Date(Number(deadline) * 1000).toLocaleDateString() : '—'}</td>
      <td style={{ padding: 8 }}>{d.reason.length > 40 ? d.reason.slice(0, 40) + '...' : d.reason}</td>
      <td style={{ padding: 8 }}><button onClick={onSelect}>View</button></td>
    </tr>
  )
}
```

Update table headers accordingly:
```tsx
<th style={{ padding: 8 }}>ID</th>
<th style={{ padding: 8 }}>Market</th>
<th style={{ padding: 8 }}>Type</th>
<th style={{ padding: 8 }}>State</th>
<th style={{ padding: 8 }}>Deadline</th>
<th style={{ padding: 8 }}>Reason</th>
<th style={{ padding: 8 }}></th>
```

**Step 2: Verify TypeScript compiles**

Run: `cd frontend && npx tsc --noEmit`
Expected: No errors

**Step 3: Commit**

```bash
git add frontend/src/pages/HumanHouse.tsx
git commit -m "feat: add dispute state and deadline to list rows"
```

---

### Task 8: Final Verification

**Step 1: Run full TypeScript check**

Run: `cd frontend && npx tsc --noEmit`
Expected: No errors

**Step 2: Run frontend dev build**

Run: `cd frontend && npx vite build`
Expected: Build succeeds

**Step 3: Final commit if any fixes needed**

```bash
git add -A
git commit -m "feat: HumanHouse frontend complete"
```
