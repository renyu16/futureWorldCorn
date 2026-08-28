import { useAccount } from 'wagmi'
import { formatEther } from 'viem'
import { useUserPositions, type UserPosition } from '../hooks/useUserPositions'
import { useTokenBalance } from '../hooks/useToken'
import { useWriteClaimReward } from '../hooks/useMarket'
import { PREDICTION_MARKET_ADDRESS, predictionMarketABI } from '../contracts/abi'
import { Card, CardContent } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { useToast } from '../components/Toast'
import { Skeleton } from '@/components/ui/skeleton'
import { useCallback } from 'react'

function PositionCard({ position }: { position: UserPosition }) {
  const { toast } = useToast()
  const { marketId, question, sharesYes, sharesNo, outcomeYes, outcomeNo, status, result } = position
  const { writeContract, isPending } = useWriteClaimReward()

  const totalShares = sharesYes + sharesNo
  const yesPercent = outcomeYes > 0n ? Number((sharesYes * 10000n) / outcomeYes) / 100 : 0
  const noPercent = outcomeNo > 0n ? Number((sharesNo * 10000n) / outcomeNo) / 100 : 0

  const statusLabel = ['进行中', '已结算', '已取消'][status] ?? '未知'

  const canClaim = status === 1 && totalShares > 0n

  const handleClaim = useCallback(() => {
    writeContract(
      {
        address: PREDICTION_MARKET_ADDRESS as `0x${string}`,
        abi: predictionMarketABI,
        functionName: 'claimReward',
        args: [BigInt(marketId)],
      },
      {
        onSuccess: () => toast('奖励领取成功！', 'success'),
        onError: (e) => toast(`领取失败: ${e.message}`, 'error'),
      }
    )
  }, [marketId, writeContract, toast])

  return (
    <Card className="hover:shadow-md transition-shadow">
      <CardContent className="p-4 space-y-3">
        <div className="flex items-start justify-between gap-2">
          <p className="font-medium leading-snug">{question}</p>
          <Badge variant={status === 0 ? 'default' : status === 1 ? 'success' : 'secondary'} className="shrink-0">
            {statusLabel}
          </Badge>
        </div>

        <div className="space-y-2">
          <div className="flex items-center justify-between text-sm">
            <span className="text-muted">是 (Yes)</span>
            <span className="font-mono">{Number(sharesYes) > 0 ? `${yesPercent.toFixed(1)}%` : '-'}</span>
          </div>
          <div className="h-1.5 bg-muted rounded-full overflow-hidden">
            <div
              className="h-full bg-yes rounded-full transition-all"
              style={{ width: `${yesPercent}%` }}
            />
          </div>

          <div className="flex items-center justify-between text-sm">
            <span className="text-muted">否 (No)</span>
            <span className="font-mono">{Number(sharesNo) > 0 ? `${noPercent.toFixed(1)}%` : '-'}</span>
          </div>
          <div className="h-1.5 bg-muted rounded-full overflow-hidden">
            <div
              className="h-full bg-no rounded-full transition-all"
              style={{ width: `${noPercent}%` }}
            />
          </div>
        </div>

        <div className="flex items-center justify-between text-xs text-muted">
          <span>持仓: {Number(totalShares) > 0 ? `${Number(formatEther(totalShares)).toFixed(4)} 份额` : '无'}</span>
          {status === 1 && (
            <span className={result ? 'text-yes' : 'text-no'}>
              结果: {result ? '是' : '否'}
            </span>
          )}
        </div>

        {canClaim && (
          <Button
            size="sm"
            onClick={handleClaim}
            disabled={isPending}
            className="w-full"
          >
            {isPending ? '领取中...' : '领取奖励'}
          </Button>
        )}
      </CardContent>
    </Card>
  )
}

export function Portfolio() {
  const { address } = useAccount()
  const { positions, isLoading } = useUserPositions(address)
  const { data: balance } = useTokenBalance(address)

  const totalShares = positions.reduce((sum, p) => sum + p.totalShares, 0n)
  const activePositions = positions.filter(p => p.status === 0)
  const resolvedPositions = positions.filter(p => p.status === 1)

  return (
    <div className="space-y-6">
      <h2 className="text-xl font-bold">投资组合</h2>
      {address ? (
        <div className="space-y-6">
          <Card>
            <CardContent className="space-y-2 p-6">
              <div className="flex justify-between">
                <span className="text-muted">钱包</span>
                <span className="font-mono text-sm truncate">{address.slice(0, 6)}...{address.slice(-4)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted">CORN 余额</span>
                <span className="font-medium">{balance ? (Number(balance) / 1e18).toFixed(4) : '0'} CORN</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted">持仓市场</span>
                <span className="font-medium">{positions.length}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted">总份额</span>
                <span className="font-medium">{Number(totalShares) > 0 ? Number(formatEther(totalShares)).toFixed(4) : '0'}</span>
              </div>
            </CardContent>
          </Card>

          {isLoading ? (
            <div className="space-y-3">
              <div className="flex items-center gap-2 text-sm text-muted">
                <div className="h-4 w-4 animate-spin rounded-full border-2 border-primary border-t-transparent" />
                <span>正在连接 RPC 节点...</span>
              </div>
              <Skeleton className="h-32 w-full" />
              <Skeleton className="h-32 w-full" />
              <Skeleton className="h-32 w-full" />
            </div>
          ) : positions.length === 0 ? (
            <div className="text-center py-12">
              <p className="text-muted mb-2">暂无持仓</p>
              <p className="text-xs text-muted">参与市场预测后，您的持仓将显示在这里</p>
            </div>
          ) : (
            <div className="space-y-4">
              {activePositions.length > 0 && (
                <div className="space-y-3">
                  <h3 className="font-semibold text-sm text-muted">进行中 ({activePositions.length})</h3>
                  {activePositions.map(p => <PositionCard key={p.marketId} position={p} />)}
                </div>
              )}
              {resolvedPositions.length > 0 && (
                <div className="space-y-3">
                  <h3 className="font-semibold text-sm text-muted">已结算 ({resolvedPositions.length})</h3>
                  {resolvedPositions.map(p => <PositionCard key={p.marketId} position={p} />)}
                </div>
              )}
            </div>
          )}
        </div>
      ) : (
        <Card><CardContent className="p-6 text-muted">连接钱包以查看投资组合。</CardContent></Card>
      )}
    </div>
  )
}
