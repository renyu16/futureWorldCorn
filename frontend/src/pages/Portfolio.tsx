import { useAccount } from 'wagmi'
import { useMarketCount, useMarketTuple } from '../hooks/useMarket'
import { useTokenBalance } from '../hooks/useToken'
import { Card, CardContent } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'

function MarketPosition({ marketId }: { marketId: number }) {
  const { data: market } = useMarketTuple(marketId)
  if (!market) return null
  const [question, , , , status] = market
  const statusLabel = ['Open', 'Resolved', 'Cancelled'][status as number] ?? 'Unknown'
  return (
    <Card>
      <CardContent className="flex items-center justify-between p-4">
        <div>
          <p className="font-medium">{question}</p>
          <p className="text-xs text-muted">Market #{marketId}</p>
        </div>
        <Badge variant={status === 0 ? 'default' : status === 1 ? 'success' : 'secondary'}>{statusLabel}</Badge>
      </CardContent>
    </Card>
  )
}

export function Portfolio() {
  const { address } = useAccount()
  const { data: count } = useMarketCount()
  const { data: balance } = useTokenBalance(address)
  const total = Number(count ?? 0)
  const ids = Array.from({ length: total }, (_, i) => i)

  return (
    <div className="space-y-6">
      <h2 className="text-xl font-bold">Portfolio</h2>
      {address ? (
        <div className="space-y-6">
          <Card>
            <CardContent className="space-y-2 p-6">
              <div className="flex justify-between"><span className="text-muted">Wallet</span><span className="font-mono text-sm">{address}</span></div>
              <div className="flex justify-between"><span className="text-muted">CORN Balance</span><span className="font-medium">{balance ? (Number(balance) / 1e18).toFixed(4) : '0'} CORN</span></div>
            </CardContent>
          </Card>
          <div className="space-y-3">
            <h3 className="font-semibold">Your Markets</h3>
            {total === 0 ? <p className="text-muted">No markets found.</p> : ids.map((id) => <MarketPosition key={id} marketId={id} />)}
          </div>
        </div>
      ) : (
        <Card><CardContent className="p-6 text-muted">Connect your wallet to view portfolio.</CardContent></Card>
      )}
    </div>
  )
}
