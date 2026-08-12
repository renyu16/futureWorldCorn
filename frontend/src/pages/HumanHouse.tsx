import { useEffect, useState } from 'react'
import { useAccount, usePublicClient, useReadContract, useWriteContract } from 'wagmi'
import { formatEther } from 'viem'
import {
  CORN_TOKEN_ADDRESS, cornTokenABI,
  HUMAN_HOUSE_ADDRESS, humanHouseABI,
} from '../contracts/abi'
import {
  useDispute, useDisputeDeposit, useRaiseDispute, useVote, useExecuteDispute,
  fetchDisputeCreatedLogs,
} from '../hooks/useHumanHouse'

const DISPUTE_TYPE: Record<number, string> = { 0: 'Oracle Result', 1: 'Market Content' }
const DISPUTE_STATE: Record<number, string> = { 0: 'Active', 1: 'Approved', 2: 'Rejected' }
const STATE_COLOR: Record<number, string> = { 0: '#5bc0de', 1: '#5cb85c', 2: '#d9534f' }

const MOCK_ROOT = 0n
const MOCK_NULLIFIER_HASH = 0n
const MOCK_PROOF = [0n, 0n, 0n, 0n, 0n, 0n, 0n, 0n] as [bigint, bigint, bigint, bigint, bigint, bigint, bigint, bigint]

interface DisputeInfo {
  id: bigint
  marketId: bigint
  disputeType: number
  reason: string
}

function DisputeDetail({ id, onBack }: { id: bigint; onBack: () => void }) {
  const { address } = useAccount()
  const { data: dispute } = useDispute(id)
  const { writeContract: writeVote } = useVote()
  const { writeContract: writeExecute } = useExecuteDispute()

  if (!dispute) return <p>Loading dispute #{id.toString()}...</p>

  const [marketId, disputeType, state, initiator, deposit, deadline, reason, votesFor, votesAgainst] = dispute as any
  const isActive = Number(state) === 0
  const isExpired = Date.now() / 1000 > Number(deadline)

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

      {isActive && !isExpired && address && (
        <div style={{ marginTop: 16, border: '1px solid #ccc', padding: 12, borderRadius: 6 }}>
          <h4>World ID Verification (Mock)</h4>
          <p style={{ fontSize: 12, color: '#888' }}>Currently using mock proof. Real World ID integration coming soon.</p>
          <button
            onClick={() => writeVote({
              address: HUMAN_HOUSE_ADDRESS,
              abi: humanHouseABI,
              functionName: 'vote',
              args: [id, true, MOCK_ROOT, MOCK_NULLIFIER_HASH, MOCK_PROOF],
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
              args: [id, false, MOCK_ROOT, MOCK_NULLIFIER_HASH, MOCK_PROOF],
            })}
            style={{ background: '#d9534f', color: '#fff', border: 'none', padding: '8px 16px', borderRadius: 4, cursor: 'pointer' }}
          >
            Vote Against
          </button>
        </div>
      )}

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

function RaiseDispute({ onCreated }: { onCreated: () => void }) {
  const { address } = useAccount()
  const [marketId, setMarketId] = useState('')
  const [disputeType, setDisputeType] = useState('0')
  const [reason, setReason] = useState('')
  const { writeContract } = useRaiseDispute()
  const { writeContract: writeApprove } = useWriteContract()

  const { data: disputeDeposit } = useDisputeDeposit()
  const deposit = (disputeDeposit as bigint | undefined) ?? 0n
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: CORN_TOKEN_ADDRESS,
    abi: cornTokenABI,
    functionName: 'allowance',
    args: address ? [address, HUMAN_HOUSE_ADDRESS] : undefined,
  })

  const needsApprove = deposit > (allowance as bigint)
  const validMarketId = /^\d+$/.test(marketId)

  return (
    <div style={{ border: '1px solid #ccc', padding: 12, borderRadius: 6, marginBottom: 16 }}>
      <h3>Raise Dispute</h3>
      {deposit > 0n && <p>Required deposit: {formatEther(deposit)} CORN</p>}
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
              args: [HUMAN_HOUSE_ADDRESS, deposit],
            }, { onSuccess: () => refetchAllowance() })}
            style={{ marginRight: 8 }}
          >
            Approve CORN
          </button>
        )}
        <button
          disabled={!validMarketId || !reason || !!needsApprove}
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

export function HumanHouse() {
  const { address } = useAccount()
  const publicClient = usePublicClient()
  const [disputes, setDisputes] = useState<DisputeInfo[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [selectedId, setSelectedId] = useState<bigint | null>(null)

  useEffect(() => {
    if (!publicClient) return
    setLoading(true)
    setError(null)
    fetchDisputeCreatedLogs(publicClient).then((logs: any[]) => {
      setDisputes(logs.map(l => ({
        id: l.args.disputeId as bigint,
        marketId: l.args.marketId as bigint,
        disputeType: Number(l.args.disputeType),
        reason: l.args.reason as string,
      })).reverse())
      setLoading(false)
    }).catch((e) => {
      console.error('Failed to fetch disputes:', e)
      setError('Failed to load disputes')
      setLoading(false)
    })
  }, [publicClient])

  if (selectedId !== null) {
    return <DisputeDetail id={selectedId} onBack={() => setSelectedId(null)} />
  }

  return (
    <div>
      <h2>HumanHouse Disputes</h2>
      <RaiseDispute onCreated={() => setLoading(true)} />
      {!address ? <p>Connect your wallet to view disputes.</p> : loading ? <p>Loading disputes...</p> : error ? <p style={{ color: '#d9534f' }}>{error}</p> : disputes.length === 0 ? <p>No disputes yet.</p> : (
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ textAlign: 'left', borderBottom: '2px solid #ccc' }}>
              <th style={{ padding: 8 }}>ID</th>
              <th style={{ padding: 8 }}>Market</th>
              <th style={{ padding: 8 }}>Type</th>
              <th style={{ padding: 8 }}>State</th>
              <th style={{ padding: 8 }}>Deadline</th>
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
