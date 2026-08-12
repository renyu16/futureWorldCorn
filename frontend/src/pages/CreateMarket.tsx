import { useState } from 'react'
import { useWriteCreateMarket } from '../hooks/useMarket'
import { predictionMarketABI, PREDICTION_MARKET_ADDRESS } from '../contracts/abi'

export function CreateMarket() {
  const { writeContract } = useWriteCreateMarket()
  const [question, setQuestion] = useState('')
  const [deadline, setDeadline] = useState('')
  const [feeBps, setFeeBps] = useState('')
  const [status, setStatus] = useState('')

  const handleCreate = async () => {
    if (!question || !deadline) return

    const deadlineUnix = BigInt(Math.floor(new Date(deadline).getTime() / 1000))
    const fee = feeBps ? Number(feeBps) : 0

    writeContract({
      address: PREDICTION_MARKET_ADDRESS,
      abi: predictionMarketABI,
      functionName: 'createMarket',
      args: [question, Number(deadlineUnix), fee],
    })

    setStatus('Transaction submitted. Check wallet to confirm.')
  }

  return (
    <div>
      <h2>Create Market</h2>
      <div>
        <label>Question:</label><br />
        <input
          type="text"
          value={question}
          onChange={(e) => setQuestion(e.target.value)}
          placeholder="e.g. Will ETH reach $10k by end of 2026?"
          style={{ width: 400 }}
        />
      </div>
      <div style={{ marginTop: 8 }}>
        <label>Deadline:</label><br />
        <input
          type="datetime-local"
          value={deadline}
          onChange={(e) => setDeadline(e.target.value)}
        />
      </div>
      <div style={{ marginTop: 8 }}>
        <label>Fee (basis points, optional):</label><br />
        <input
          type="number"
          value={feeBps}
          onChange={(e) => setFeeBps(e.target.value)}
          placeholder="e.g. 250 = 2.5%"
          min="0"
          max="10000"
        />
      </div>
      <div style={{ marginTop: 16 }}>
        <button onClick={handleCreate} disabled={!question || !deadline}>
          Create Market
        </button>
      </div>
      {status && <p>{status}</p>}
    </div>
  )
}
