import { useMarketCount, useMarketTuple } from '../hooks/useMarket'

interface Props {
  onSelect: (id: number) => void
}

function MarketCard({ id, onSelect }: { id: number; onSelect: (id: number) => void }) {
  const { data: market, isLoading } = useMarketTuple(id)

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
      <button onClick={() => onSelect(id)}>View Details</button>
    </div>
  )
}

export function MarketList({ onSelect }: Props) {
  const { data: count, isLoading, isError, error, isPending, isFetched } = useMarketCount()

  if (isLoading) return <div>Loading markets...</div>
  if (isPending && !isFetched) return <div>Pending markets...</div>
  if (isError) return <div>Market count error: {String(error?.shortMessage || error?.message || error)}</div>

  const total = Number(count ?? 0)

  if (total === 0) return <div>No markets yet.</div>

  const ids = Array.from({ length: total }, (_, i) => i + 1)

  return (
    <div>
      <h2>Markets ({total})</h2>
      {ids.map((id) => (
        <MarketCard key={id} id={id} onSelect={onSelect} />
      ))}
    </div>
  )
}
