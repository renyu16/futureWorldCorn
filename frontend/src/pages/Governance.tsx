import { useEffect, useState } from 'react'
import { useAccount, usePublicClient } from 'wagmi'
import { formatEther } from 'viem'
import {
  TOKEN_HOUSE_ADDRESS, tokenHouseABI,
  GOV_CORN_TOKEN_ADDRESS, govCrownTokenABI,
} from '../contracts/abi'
import {
  useProposalState, useProposalVotes, useProposalProposer,
  useProposalDeadline, useProposalSnapshot, useCastVote,
} from '../hooks/useGovernance'
import { useReadContract } from 'wagmi'

const STATE_LABEL: Record<string, string> = {
  Pending: 'Pending', Active: 'Active', Canceled: 'Canceled', Defeated: 'Defeated',
  Succeeded: 'Succeeded', Queued: 'Queued', Expired: 'Expired', Executed: 'Executed',
}

const STATE_COLOR: Record<string, string> = {
  Pending: '#f0ad4e', Active: '#5bc0de', Succeeded: '#5cb85c',
  Queued: '#5cb85c', Executed: '#5cb85c', Defeated: '#d9534f',
  Canceled: '#888', Expired: '#888',
}

function ProposalDetail({ id, onBack }: { id: bigint; onBack: () => void }) {
  const { data: state } = useProposalState(id)
  const { data: votes } = useProposalVotes(id)
  const { data: proposer } = useProposalProposer(id)
  const { data: deadline } = useProposalDeadline(id)
  const { data: snapshot } = useProposalSnapshot(id)
  const { writeContract } = useCastVote()
  const { address } = useAccount()

  const { data: userVotes } = useReadContract({
    address: GOV_CORN_TOKEN_ADDRESS,
    abi: govCrownTokenABI,
    functionName: 'getVotes',
    args: address ? [address] : undefined,
  })

  const against = votes ? (votes as [bigint, bigint, bigint])[0] : undefined
  const forVotes = votes ? (votes as [bigint, bigint, bigint])[1] : undefined
  const abstain = votes ? (votes as [bigint, bigint, bigint])[2] : undefined

  return (
    <div>
      <button onClick={onBack} style={{ marginBottom: 12 }}>&larr; Back</button>
      <h3>Proposal #{id.toString()}</h3>
      <p>State: <span style={{ color: STATE_COLOR[state as string || ''] }}>{state as string || '—'}</span></p>
      <p>Proposer: <code>{proposer as string || '—'}</code></p>
      <p>Snapshot Block: {snapshot?.toString() || '—'}</p>
      <p>Deadline Block: {deadline?.toString() || '—'}</p>
      <p>For: <strong>{forVotes !== undefined ? formatEther(forVotes) : '—'}</strong> govCORN</p>
      <p>Against: <strong>{against !== undefined ? formatEther(against) : '—'}</strong> govCORN</p>
      <p>Abstain: <strong>{abstain !== undefined ? formatEther(abstain) : '—'}</strong> govCORN</p>

      {state === 'Active' && address && (
        <div style={{ marginTop: 16 }}>
          <p>Your Voting Power: {userVotes ? formatEther(userVotes as bigint) : '0'} govCORN</p>
          {userVotes !== undefined && (userVotes as bigint) > 0n && (
            <div>
              <button
                onClick={() => writeContract({
                  address: TOKEN_HOUSE_ADDRESS, abi: tokenHouseABI,
                  functionName: 'castVote',
                  args: [id, 1],
                })}
                style={{ marginRight: 8, background: '#5cb85c', color: '#fff', border: 'none', padding: '8px 16px', borderRadius: 4, cursor: 'pointer' }}
              >For</button>
              <button
                onClick={() => writeContract({
                  address: TOKEN_HOUSE_ADDRESS, abi: tokenHouseABI,
                  functionName: 'castVote',
                  args: [id, 0],
                })}
                style={{ marginRight: 8, background: '#d9534f', color: '#fff', border: 'none', padding: '8px 16px', borderRadius: 4, cursor: 'pointer' }}
              >Against</button>
              <button
                onClick={() => writeContract({
                  address: TOKEN_HOUSE_ADDRESS, abi: tokenHouseABI,
                  functionName: 'castVote',
                  args: [id, 2],
                })}
                style={{ background: '#888', color: '#fff', border: 'none', padding: '8px 16px', borderRadius: 4, cursor: 'pointer' }}
              >Abstain</button>
            </div>
          )}
        </div>
      )}
    </div>
  )
}

export function Governance() {
  const { address } = useAccount()
  const publicClient = usePublicClient()
  const [proposals, setProposals] = useState<Array<{ id: bigint; description: string }>>([])
  const [loading, setLoading] = useState(true)
  const [selectedId, setSelectedId] = useState<bigint | null>(null)

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
      setProposals((logs as any[]).map(l => ({
        id: (l.args as any).proposalId as bigint,
        description: (l.args as any).description as string,
      })).reverse())
      setLoading(false)
    }).catch(() => setLoading(false))
  }, [publicClient])

  if (selectedId !== null) {
    return <ProposalDetail id={selectedId} onBack={() => setSelectedId(null)} />
  }

  return (
    <div>
      <h2>Governance</h2>
      {loading ? <p>Loading proposals...</p> : proposals.length === 0 ? <p>No proposals yet.</p> : (
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ textAlign: 'left', borderBottom: '2px solid #ccc' }}>
              <th style={{ padding: 8 }}>ID</th>
              <th style={{ padding: 8 }}>Description</th>
              <th style={{ padding: 8 }}>Status</th>
              <th style={{ padding: 8 }}></th>
            </tr>
          </thead>
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
  const { data: state } = useProposalState(p.id)
  const desc = p.description.length > 100 ? p.description.slice(0, 100) + '…' : p.description
  return (
    <tr style={{ borderBottom: '1px solid #eee' }}>
      <td style={{ padding: 8 }}>{p.id.toString()}</td>
      <td style={{ padding: 8 }}>{desc}</td>
      <td style={{ padding: 8 }}>
        <span style={{ color: STATE_COLOR[state as string || ''], fontWeight: 'bold' }}>
          {STATE_LABEL[state as string || ''] || '—'}
        </span>
      </td>
      <td style={{ padding: 8 }}>
        <button onClick={onSelect}>View</button>
      </td>
    </tr>
  )
}
