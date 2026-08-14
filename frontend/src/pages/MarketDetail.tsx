import { useAccount, useReadContract } from 'wagmi'
import { useMarketTuple, useWriteBet, useWriteClaimReward, useWriteResolveMarket } from '../hooks/useMarket'
import { useTokenBalance, useTokenAllowance, useWriteApprove } from '../hooks/useToken'
import { CORN_TOKEN_ADDRESS, cornTokenABI, PREDICTION_MARKET_ADDRESS, predictionMarketABI } from '../contracts/abi'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { TradingPanel } from '@/components/TradingPanel'
import { ArrowLeft } from 'lucide-react'

interface Props {
  marketId: number
  onBack: () => void
}

export function MarketDetail({ marketId, onBack }: Props) {
  const { address } = useAccount()
  const { data: market, isLoading } = useMarketTuple(marketId)
  const { data: balance } = useTokenBalance(address)
  const { data: allowance } = useTokenAllowance(address, PREDICTION_MARKET_ADDRESS)
  const { data: owner } = useReadContract({
    address: PREDICTION_MARKET_ADDRESS,
    abi: predictionMarketABI,
    functionName: 'owner',
  })
  const { data: isResolver } = useReadContract({
    address: PREDICTION_MARKET_ADDRESS,
    abi: predictionMarketABI,
    functionName: 'resolvers',
    args: address ? [address] : undefined,
  })
  const { writeContract: approve } = useWriteApprove()
  const { writeContract: bet } = useWriteBet()
  const { writeContract: claim } = useWriteClaimReward()
  const { writeContract: resolve } = useWriteResolveMarket()

  if (isLoading) return <p className="text-muted">加载市场中...</p>
  if (!market) return <p className="text-muted">未找到市场</p>

  const [question, outcomeYes, outcomeNo, deadline, status, result, feeBps] = market
  const statusLabel = ['进行中', '已结算', '已取消'][status as number] ?? '未知'
  const yesPool = Number(outcomeYes) / 1e18
  const noPool = Number(outcomeNo) / 1e18
  const userBalance = balance ? Number(balance) / 1e18 : 0
  const userAllowance = allowance ? Number(allowance) / 1e18 : 0
  const isOpen = status === 0
  const isResolved = status === 1
  const isOwner = address && owner ? address.toLowerCase() === (owner as string).toLowerCase() : false
  const canResolve = isOwner || (isResolver as boolean) === true
  const deadlinePassed = Number(deadline) * 1000 < Date.now()

  const handleBet = async (outcome: number, amt: string) => {
    if (!address) return
    const parsed = BigInt(Math.floor(parseFloat(amt) * 1e18))
    if (parsed <= 0n) return
    if (userAllowance < parseFloat(amt)) {
      approve({
        address: CORN_TOKEN_ADDRESS, abi: cornTokenABI, functionName: 'approve',
        args: [PREDICTION_MARKET_ADDRESS, parsed],
      })
    } else {
      bet({
        address: PREDICTION_MARKET_ADDRESS, abi: predictionMarketABI, functionName: 'bet',
        args: [BigInt(marketId), outcome, parsed],
      })
    }
  }

  const handleApprove = async (amt: string) => {
    const parsed = BigInt(Math.floor(parseFloat(amt) * 1e18))
    if (parsed <= 0n) return
    approve({
      address: CORN_TOKEN_ADDRESS, abi: cornTokenABI, functionName: 'approve',
      args: [PREDICTION_MARKET_ADDRESS, parsed],
    })
  }

  const handleClaim = async () => {
    claim({
      address: PREDICTION_MARKET_ADDRESS, abi: predictionMarketABI, functionName: 'claimReward',
      args: [BigInt(marketId)],
    })
  }

  const handleResolve = async (win: boolean) => {
    resolve({
      address: PREDICTION_MARKET_ADDRESS, abi: predictionMarketABI, functionName: 'resolveMarket',
      args: [BigInt(marketId), win],
    })
  }

  return (
    <div className="space-y-4">
      <Button variant="ghost" size="sm" onClick={onBack} className="text-muted">
        <ArrowLeft className="mr-2 h-4 w-4" /> 返回
      </Button>
      <Card>
        <CardHeader>
          <div className="flex items-start justify-between gap-2">
            <CardTitle className="text-xl">{question}</CardTitle>
            <Badge variant={status === 0 ? 'default' : status === 1 ? 'success' : 'secondary'}>{statusLabel}</Badge>
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-2 gap-4 text-sm">
            <div><span className="text-muted">截止时间：</span><br />{new Date(Number(deadline) * 1000).toLocaleString()}</div>
            <div><span className="text-muted">结果：</span><br />{isResolved ? (result ? 'YES 胜' : 'NO 胜') : '-'}</div>
            <div><span className="text-yes font-medium">YES 资金池：</span><br />{yesPool.toFixed(4)} CORN</div>
            <div><span className="text-no font-medium">NO 资金池：</span><br />{noPool.toFixed(4)} CORN</div>
          </div>
          <div className="rounded-lg bg-muted/10 p-3 text-sm">
            <span className="text-muted">您的余额：</span> <span className="font-medium">{userBalance.toFixed(4)} CORN</span>
          </div>

          {isOpen && !deadlinePassed && (
            <div className="space-y-3 border-t border-border pt-4">
              <h3 className="font-semibold">下注</h3>
              <TradingPanel
                yesPool={yesPool}
                noPool={noPool}
                feeBps={Number(feeBps) || 0}
                userBalance={userBalance}
                userAllowance={userAllowance}
                connected={!!address}
                onBet={handleBet}
                onApprove={handleApprove}
              />
            </div>
          )}

          {isResolved && address && (
            <div className="border-t border-border pt-4">
              <Button className="w-full" onClick={handleClaim}>领取奖励</Button>
            </div>
          )}

          {isOpen && canResolve && deadlinePassed && (
            <div className="space-y-3 border-t border-border pt-4">
              <h3 className="font-semibold">结算市场</h3>
              <p className="text-sm text-muted">截止时间已过，请选择获胜结果。</p>
              <div className="flex gap-2">
                <Button className="flex-1" variant="outline" onClick={() => handleResolve(true)}>结算为 YES 胜</Button>
                <Button className="flex-1" variant="outline" onClick={() => handleResolve(false)}>结算为 NO 胜</Button>
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
