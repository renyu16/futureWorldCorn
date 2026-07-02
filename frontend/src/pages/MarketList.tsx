import { useMarketCount, useMarket } from '../hooks/useMarket'

interface Props {
  onSelect: (id: number) => void
}

function MarketCard({ id, onSelect }: { id: number; onSelect: (id: number) => void }) {
  const { data: market, isLoading } = useMarket(id)

  if (isLoading) return <div>Loading market {id}...</div>

  if (!market) return <div>Market {id} not found</div>

  const [question, outcomeYes, outcomeNo, deadline, status, result] = market
  const statusLabel = ['Open', 'Resolved', 'Cancelled'][status as number] ?? 'Unknown'
  const yesPool = Number(outcomeYes) / 1e18
  const noPool = Number(outcomeNo) / 1e18
  const deadlineStr = new Date(Number(deadline) * 1000).toLocaleString()

  return (
    <div style={{ border: '1px solid #ccc', padding: 12, margin: 8, borderRadius: 8 }}>
      <h3>{question}</h3>
      <p>Deadline: {deadlineStr}</p>
      <p>Status: {statusLabel}{status === 1 && ` - ${result ? 'YES' : 'NO'}`}</p>
      <p>YES Pool: {yesPool.toFixed(4)} | NO Pool: {noPool.toFixed(4)}</p>
      <button onClick={() => onSelect(id)} disabled={status === 1}>View Details</button>
    </div>
  )
}

export function MarketList({ onSelect }: Props) {
  const { data: count, isLoading } = useMarketCount()

  if (isLoading) return <div>Loading markets...</div>

  const total = Number(count ?? 0)

  if (total === 0) return <div>No markets yet.</div>

  const ids = Array.from({ length: total }, (_, i) => i)

  return (
    <div>
      <h2>Markets ({total})</h2>
      {ids.map((id) => (
        <MarketCard key={id} id={id} onSelect={onSelect} />
      ))}
    </div>
  )
}
