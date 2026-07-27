import { useEffect, useState } from 'react'
import { useAccount, usePublicClient, useReadContract } from 'wagmi'
import { formatEther, encodeFunctionData } from 'viem'
import {
  TOKEN_HOUSE_ADDRESS, tokenHouseABI,
  GOV_CORN_TOKEN_ADDRESS, govCrownTokenABI,
} from '../contracts/abi'
import {
  useProposalState, useProposalVotes, useProposalProposer,
  useProposalDeadline, useProposalSnapshot, useCastVote,
  usePropose, useProposalThreshold,
} from '../hooks/useGovernance'

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

function CreateProposal({ onCreated }: { onCreated: () => void }) {
  const { address } = useAccount()
  const [target, setTarget] = useState('')
  const [value, setValue] = useState('0')
  const [funcSig, setFuncSig] = useState('')
  const [argsJson, setArgsJson] = useState('[]')
  const [description, setDescription] = useState('')
  const [error, setError] = useState<string | null>(null)
  const { writeContract } = usePropose()

  const { data: threshold } = useProposalThreshold()
  const { data: userVotes } = useReadContract({
    address: GOV_CORN_TOKEN_ADDRESS,
    abi: govCrownTokenABI,
    functionName: 'getVotes',
    args: address ? [address] : undefined,
  })

  const canPropose = threshold !== undefined && userVotes !== undefined && (userVotes as bigint) >= (threshold as bigint)
  const validAddress = /^0x[a-fA-F0-9]{40}$/.test(target)

  const handleSubmit = () => {
    setError(null)
    try {
      const abi = funcSig ? [`function ${funcSig}`] as const : ['function ()'] as const
      const fnName = funcSig ? funcSig.split('(')[0] : ''
      const args = funcSig ? JSON.parse(argsJson) : []
      const calldata = funcSig
        ? encodeFunctionData({ abi, functionName: fnName, args })
        : '0x'

      writeContract({
        address: TOKEN_HOUSE_ADDRESS,
        abi: tokenHouseABI,
        functionName: 'propose',
        args: [
          [target as `0x${string}`],
          [BigInt(value || '0')],
          [calldata as `0x${string}`],
          description,
        ],
      }, {
        onSuccess: () => { setTarget(''); setValue('0'); setFuncSig(''); setArgsJson('[]'); setDescription(''); onCreated() },
      })
    } catch (e: any) {
      setError(e.message || 'Failed to build calldata')
    }
  }

  return (
    <div style={{ border: '1px solid #ccc', padding: 12, borderRadius: 6, marginBottom: 16 }}>
      <h3>Create Proposal</h3>
      <p>Voting Power: <strong>{userVotes ? formatEther(userVotes as bigint) : '0'}</strong> govCORN</p>
      <p>Required: <strong>{threshold ? formatEther(threshold as bigint) : '-'}</strong> govCORN (1% of supply)</p>
      {!canPropose && threshold !== undefined && (
        <p style={{ color: '#d9534f', fontSize: 12 }}>Insufficient voting power to propose. Delegate or acquire more govCORN.</p>
      )}
      <div style={{ marginBottom: 8 }}>
        <label>Target address: </label><br />
        <input value={target} onChange={e => setTarget(e.target.value)} placeholder="0x..." style={{ width: 400 }} />
      </div>
      <div style={{ marginBottom: 8 }}>
        <label>ETH value (wei): </label><br />
        <input value={value} onChange={e => setValue(e.target.value)} placeholder="0" style={{ width: 200 }} />
      </div>
      <div style={{ marginBottom: 8 }}>
        <label>Function signature (optional, e.g. transfer(address,uint256)): </label><br />
        <input value={funcSig} onChange={e => setFuncSig(e.target.value)} placeholder="transfer(address,uint256)" style={{ width: 400 }} />
      </div>
      {funcSig && (
        <div style={{ marginBottom: 8 }}>
          <label>Arguments (JSON array): </label><br />
          <input value={argsJson} onChange={e => setArgsJson(e.target.value)} placeholder='["0x1234...", 1000000000000000000]' style={{ width: 400 }} />
        </div>
      )}
      <div style={{ marginBottom: 8 }}>
        <label>Description: </label><br />
        <textarea value={description} onChange={e => setDescription(e.target.value)} rows={3} style={{ width: 400 }} />
      </div>
      {error && <p style={{ color: '#d9534f', fontSize: 12 }}>{error}</p>}
      <button
        disabled={!canPropose || !validAddress || !description}
        onClick={handleSubmit}
      >
        Submit Proposal
      </button>
    </div>
  )
}

export function Governance() {
  const { address } = useAccount()
  const publicClient = usePublicClient()
  const [proposals, setProposals] = useState<Array<{ id: bigint; description: string }>>([])
  const [loading, setLoading] = useState(true)
  const [selectedId, setSelectedId] = useState<bigint | null>(null)
  const [showForm, setShowForm] = useState(false)

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
      {address && (
        <button
          onClick={() => setShowForm(!showForm)}
          style={{ marginBottom: 16 }}
        >
          {showForm ? 'Cancel' : 'Create Proposal'}
        </button>
      )}
      {showForm && <CreateProposal onCreated={() => { setShowForm(false); setLoading(true) }} />}
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
