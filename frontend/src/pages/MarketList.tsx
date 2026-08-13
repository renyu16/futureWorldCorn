import { useMarketCount, useMarketTuple } from '../hooks/useMarket'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'

interface Props {
  onSelect: (id: number) => void
}

function MarketCard({ id, onSelect }: { id: number; onSelect: (id: number) => void }) {
  const { data: market, isLoading } = useMarketTuple(id)

  if (isLoading) return <Card className="animate-pulse"><CardContent className="h-40" /></Card>
  if (!market) return null

  const [question, outcomeYes, outcomeNo, deadline, status, result] = market
  const statusLabel = ['Open', 'Resolved', 'Cancelled'][status as number] ?? 'Unknown'
  const yesPool = Number(outcomeYes) / 1e18
  const noPool = Number(outcomeNo) / 1e18
  const deadlineStr = new Date(Number(deadline) * 1000).toLocaleString()
  const totalPool = yesPool + noPool
  const yesPct = totalPool > 0 ? (yesPool / totalPool) * 100 : 50

  return (
    <Card>
      <CardHeader>
        <div className="flex items-start justify-between gap-2">
          <CardTitle className="text-base">{question}</CardTitle>
          <Badge variant={status === 0 ? 'default' : status === 1 ? 'success' : 'secondary'}>
            {statusLabel}
          </Badge>
        </div>
      </CardHeader>
      <CardContent className="space-y-3">
        <p className="text-xs text-muted">Deadline: {deadlineStr}</p>
        {status === 1 && <p className="text-xs text-muted">Result: {result ? 'YES Won' : 'NO Won'}</p>}
        <div className="flex h-2 overflow-hidden rounded-full bg-muted/15">
          <div className="bg-yes" style={{ width: `${yesPct}%` }} />
          <div className="bg-no" style={{ width: `${100 - yesPct}%` }} />
        </div>
        <div className="flex justify-between text-xs">
          <span className="text-yes font-medium">YES {yesPool.toFixed(2)}</span>
          <span className="text-no font-medium">NO {noPool.toFixed(2)}</span>
        </div>
        <Button className="w-full" variant="outline" onClick={() => onSelect(id)}>View Details</Button>
      </CardContent>
    </Card>
  )
}

export function MarketList({ onSelect }: Props) {
  const { data: count, isLoading, isError, error } = useMarketCount()

  if (isLoading) return <p className="text-muted">Loading markets...</p>
  if (isError) return <p className="text-no">Market count error: {String(error?.shortMessage || error?.message || error)}</p>

  const total = Number(count ?? 0)
  if (total === 0) return <p className="text-muted">No markets yet.</p>

  const ids = Array.from({ length: total }, (_, i) => i + 1)

  return (
    <div className="space-y-4">
      <h2 className="text-xl font-bold">Markets ({total})</h2>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {ids.map((id) => <MarketCard key={id} id={id} onSelect={onSelect} />)}
      </div>
    </div>
  )
}
