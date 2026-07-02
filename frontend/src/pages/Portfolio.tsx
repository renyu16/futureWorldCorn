import { useAccount } from 'wagmi'
import { useMarketCount, useMarket } from '../hooks/useMarket'
import { useTokenBalance } from '../hooks/useToken'

function MarketPosition({ marketId, user }: { marketId: number; user: `0x${string}` }) {
  const { data: market } = useMarket(marketId)
  if (!market) return null

  const [question, , , , status] = market
  const statusLabel = ['Open', 'Resolved', 'Cancelled'][status as number] ?? 'Unknown'

  return (
    <div style={{ border: '1px solid #ccc', padding: 8, margin: 4, borderRadius: 6 }}>
      <p><strong>[{statusLabel}]</strong> {question}</p>
      <p>Market #{marketId}</p>
    </div>
  )
}

export function Portfolio() {
  const { address } = useAccount()
  const { data: count } = useMarketCount()
  const { data: balance } = useTokenBalance(address)

  const total = Number(count ?? 0)
  const ids = Array.from({ length: total }, (_, i) => i)

  return (
    <div>
      <h2>Portfolio</h2>
      {address ? (
        <>
          <p>Wallet: {address}</p>
          <p>CORN Balance: {balance ? (Number(balance) / 1e18).toFixed(4) : '0'} CORN</p>

          <h3>Your Markets</h3>
          {total === 0 ? (
            <p>No markets found.</p>
          ) : (
            ids.map((id) => <MarketPosition key={id} marketId={id} user={address} />)
          )}
        </>
      ) : (
        <p>Connect your wallet to view portfolio.</p>
      )}
    </div>
  )
}
