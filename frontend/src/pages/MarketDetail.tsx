import { useEffect, useState } from 'react'
import { useParams } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import { useAccount, usePublicClient, useReadContract } from 'wagmi'
import { formatEther } from 'viem'
import { encodeFunctionData } from 'viem'
import { useMarketTuple, useWriteBet, useWriteClaimReward } from '../hooks/useMarket'
import { useTokenBalance, useTokenAllowance, useWriteApprove } from '../hooks/useToken'
import { CORN_TOKEN_ADDRESS, cornTokenABI, PREDICTION_MARKET_ADDRESS, predictionMarketABI, HUMAN_HOUSE_ADDRESS, humanHouseABI } from '../contracts/abi'
import { EXPLORER_URL, SETTLE_API_URL, SETTLE_API_TOKEN } from '../config'
import { fetchAllDisputes } from '../hooks/useHumanHouse'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { TradingPanel } from '@/components/TradingPanel'
import { Countdown } from '@/components/Countdown'
import { PriceChart, usePriceHistory } from '@/components/PriceChart'
import { MarketTimeline } from '@/components/MarketTimeline'
import { ArrowLeft, Loader2, AlertTriangle } from 'lucide-react'
import { useToast } from '../components/Toast'
import { Skeleton } from '@/components/ui/skeleton'
import { getMarketStatusLabel } from '../lib/helpers'

interface Props {
  onBack: () => void
  onRaiseDispute?: (marketId: number) => void
}

export function MarketDetail({ onBack, onRaiseDispute }: Props) {
  const { marketId: marketIdParam } = useParams<{ marketId: string }>()
  const marketId = Number(marketIdParam)
  const { toast } = useToast()

  if (isNaN(marketId)) {
    return (
      <div className="space-y-2">
        <p className="text-no">无效的市场 ID</p>
        <Button variant="outline" size="sm" onClick={onBack}>返回</Button>
      </div>
    )
  }
  const { address } = useAccount()
  const { data: market, isLoading, isError, error, refetch } = useMarketTuple(marketId)
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
  const { data: userSharesYes } = useReadContract({
    address: PREDICTION_MARKET_ADDRESS, abi: predictionMarketABI, functionName: 'sharesYes',
    args: address ? [BigInt(marketId), address] : undefined,
  })
  const { data: userSharesNo } = useReadContract({
    address: PREDICTION_MARKET_ADDRESS, abi: predictionMarketABI, functionName: 'sharesNo',
    args: address ? [BigInt(marketId), address] : undefined,
  })
  const hasShares = userSharesYes !== undefined && userSharesNo !== undefined && ((userSharesYes as bigint) + (userSharesNo as bigint)) > 0n
  const queryClient = useQueryClient()
  const { writeContract: approve, isPending: isApprovePending } = useWriteApprove()
  const { writeContract: bet, isPending: isBetPending } = useWriteBet()
  const { writeContract: claim, isPending: isClaimPending } = useWriteClaimReward()
  const publicClient = usePublicClient()
  const { data: priceHistory, isLoading: priceLoading } = usePriceHistory(marketId)
  const [disputes, setDisputes] = useState<{ id: bigint; disputeType: number; reason: string; state: number; votesFor: number; votesAgainst: number; deposit: bigint }[]>([])
  const [settle, setSettle] = useState<{
    status: 'idle' | 'pending' | 'ok' | 'manual'
    txHash?: string
    error?: string
  }>({ status: 'idle' })
  const [manual, setManual] = useState<{ payload: string; castCmd: string } | null>(null)
  const [, forceUpdate] = useState(0)
  useEffect(() => {
    const timer = setInterval(() => forceUpdate(n => n + 1), 30000)
    return () => clearInterval(timer)
  }, [])

  useEffect(() => {
    if (!publicClient) return
    let cancelled = false
    fetchAllDisputes(publicClient).then(async (allDisputes: any[]) => {
      const filtered = allDisputes.filter(d => Number(d.marketId) === marketId)
      const enriched = await Promise.all(filtered.map(async (d) => {
        const disputeId = d.id as bigint
        try {
          const data = await publicClient.readContract({
            address: HUMAN_HOUSE_ADDRESS,
            abi: humanHouseABI,
            functionName: 'disputes',
            args: [disputeId],
          })
          return {
            id: disputeId,
            disputeType: Number(d.disputeType),
            reason: d.reason as string,
            state: Number((data as any)[2]),
            votesFor: Number((data as any)[7]),
            votesAgainst: Number((data as any)[8]),
            deposit: (data as any)[4] as bigint,
          }
        } catch {
          return {
            id: disputeId,
            disputeType: Number(d.disputeType),
            reason: d.reason as string,
            state: 0,
            votesFor: 0,
            votesAgainst: 0,
            deposit: 0n,
          }
        }
      }))
      if (!cancelled) setDisputes(enriched.reverse())
    }).catch(() => {
      if (!cancelled) toast('争议数据加载失败', 'error')
    })
    return () => { cancelled = true }
  }, [publicClient?.uid, marketId])

  if (isLoading) return (
    <div className="space-y-4">
      <div className="flex items-center gap-2 text-sm text-muted">
        <div className="h-4 w-4 animate-spin rounded-full border-2 border-primary border-t-transparent" />
        <span>正在连接 RPC 节点...</span>
      </div>
      <Skeleton className="h-8 w-24" />
      <Skeleton className="h-40 w-full" />
      <Skeleton className="h-48 w-full" />
    </div>
  )
  if (isError) return (
    <div className="space-y-2">
      <p className="text-no">加载失败：{error?.message || '未知错误'}</p>
      <div className="flex gap-2">
        <Button variant="outline" size="sm" onClick={() => refetch()}>重试</Button>
        <Button variant="ghost" size="sm" onClick={onBack}>返回</Button>
      </div>
    </div>
  )
  if (!market) return (
    <div className="space-y-2">
      <p className="text-muted">未找到市场</p>
      <Button variant="outline" size="sm" onClick={onBack}>返回</Button>
    </div>
  )

  const [question, outcomeYes, outcomeNo, deadline, status, result, feeBps, resolutionSource, resolutionRule, edgeCase] = market
  const deadlinePassed = Number(deadline) * 1000 < Date.now()
  const statusLabel = getMarketStatusLabel(status, Number(deadline))
  const yesPool = Number(outcomeYes) / 1e18
  const noPool = Number(outcomeNo) / 1e18
  const userBalance = balance ? Number(balance) / 1e18 : 0
  const userAllowance = allowance ? Number(allowance) / 1e18 : 0
  const isOpen = status === 0
  const isResolved = status === 1
  const isOwner = address && owner ? address.toLowerCase() === (owner as string).toLowerCase() : false
  const canResolve = isOwner || (isResolver as boolean) === true

  const handleBet = async (outcome: number, amt: string) => {
    if (!address) return
    const parsed = BigInt(Math.floor(parseFloat(amt) * 1e18))
    if (parsed <= 0n) return
    const onError = (e: any) => toast('交易失败: ' + (e.shortMessage ?? e.message), 'error')
    try {
      if (userAllowance < parseFloat(amt)) {
        toast('交易已提交，请等待确认...', 'info')
        approve({
          address: CORN_TOKEN_ADDRESS, abi: cornTokenABI, functionName: 'approve',
          args: [PREDICTION_MARKET_ADDRESS, parsed],
        }, { onSuccess: () => queryClient.invalidateQueries({ queryKey: ['readContract'] }), onError })
      } else {
        toast('交易已提交，请等待确认...', 'info')
        bet({
          address: PREDICTION_MARKET_ADDRESS, abi: predictionMarketABI, functionName: 'bet',
          args: [BigInt(marketId), outcome, parsed],
        }, { onSuccess: () => queryClient.invalidateQueries({ queryKey: ['readContract'] }), onError })
      }
    } catch (e: any) {
      toast('交易失败: ' + (e.message || '未知错误'), 'error')
    }
  }

  const handleApprove = async (amt: string) => {
    const parsed = BigInt(Math.floor(parseFloat(amt) * 1e18))
    if (parsed <= 0n) return
    try {
      toast('交易已提交，请等待确认...', 'info')
      approve({
        address: CORN_TOKEN_ADDRESS, abi: cornTokenABI, functionName: 'approve',
        args: [PREDICTION_MARKET_ADDRESS, parsed],
      }, { onSuccess: () => queryClient.invalidateQueries({ queryKey: ['readContract'] }), onError: (e: any) => toast('交易失败: ' + (e.shortMessage ?? e.message), 'error') })
    } catch (e: any) {
      toast('交易失败: ' + (e.message || '未知错误'), 'error')
    }
  }

  const handleClaim = async () => {
    try {
      toast('交易已提交，请等待确认...', 'info')
      claim({
        address: PREDICTION_MARKET_ADDRESS, abi: predictionMarketABI, functionName: 'claimReward',
        args: [BigInt(marketId)],
      }, { onSuccess: () => queryClient.invalidateQueries({ queryKey: ['readContract'] }), onError: (e: any) => toast('交易失败: ' + (e.shortMessage ?? e.message), 'error') })
    } catch (e: any) {
      toast('交易失败: ' + (e.message || '未知错误'), 'error')
    }
  }

  const buildManualSettle = (win: boolean) => {
    const data = encodeFunctionData({
      abi: predictionMarketABI,
      functionName: 'resolveMarket',
      args: [BigInt(marketId), win],
    })
    return {
      payload: JSON.stringify({ to: PREDICTION_MARKET_ADDRESS, data, value: '0x0' }, null, 2),
      castCmd: `cast send ${PREDICTION_MARKET_ADDRESS} "resolveMarket(uint256,bool)" ${marketId} ${win}`,
    }
  }

  const copyText = async (text: string, label: string) => {
    try {
      await navigator.clipboard.writeText(text)
      toast(`${label} 已复制`, 'info')
    } catch {
      toast('复制失败', 'error')
    }
  }

  const handleResolve = async (win: boolean) => {
    if (!SETTLE_API_TOKEN) {
      setSettle({ status: 'manual', error: '未配置自动广播 token' })
      return
    }
    setSettle({ status: 'pending' })
    try {
      const res = await fetch(SETTLE_API_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${SETTLE_API_TOKEN}` },
        body: JSON.stringify({ marketId, result: win }),
      })
      const payload = await res.json().catch(() => null) as { ok?: boolean; txHash?: string; error?: string } | null
      if (res.ok && payload?.ok && payload.txHash) {
        setSettle({ status: 'ok', txHash: payload.txHash })
        toast('结算已自动广播', 'info')
        queryClient.invalidateQueries({ queryKey: ['readContract'] })
        return
      }
      setSettle({ status: 'manual', error: payload?.error })
    } catch (e: any) {
      setSettle({ status: 'manual', error: e?.message || '网络错误' })
    }
  }

  return (
    <div className="space-y-4">
      <Button variant="ghost" size="sm" onClick={onBack} className="text-muted">
        <ArrowLeft className="mr-2 h-4 w-4" /> 返回
      </Button>
      <Card>
        <CardHeader>
          <div className="flex items-start justify-between gap-2">
            <CardTitle className="min-w-0 flex-1 text-xl">{question}</CardTitle>
            <Badge className="shrink-0" variant={isResolved ? 'success' : deadlinePassed && status === 0 ? 'secondary' : status === 2 ? 'secondary' : 'default'}>{statusLabel}</Badge>
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-2 gap-4 text-sm">
            <div>
              <span className="text-muted">市场 ID：</span>
              <button
                onClick={() => { navigator.clipboard.writeText(String(marketId)).then(() => toast(`市场 #${marketId} 已复制`, 'info')).catch(() => toast('复制失败', 'error')) }}
                className="ml-1 inline-flex items-center gap-1 rounded bg-muted/10 px-1.5 py-0.5 font-mono text-muted transition-colors hover:bg-muted/20"
                title="点击复制"
              >
                #{marketId}
                <svg className="h-3 w-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
              </button>
            </div>
            <div><span className="text-muted">截止时间：</span><br />{new Date(Number(deadline) * 1000).toLocaleString()}</div>
            {isOpen && <Countdown deadline={Number(deadline)} />}
            <div><span className="text-muted">结果：</span><br />{isResolved ? (result ? 'YES 胜' : 'NO 胜') : '-'}</div>
            <div><span className="text-yes font-medium">YES 资金池：</span><br />{yesPool.toFixed(4)} CORN</div>
            <div><span className="text-no font-medium">NO 资金池：</span><br />{noPool.toFixed(4)} CORN</div>
          </div>
          {(resolutionSource || resolutionRule || edgeCase) && (
            <div className="space-y-2 rounded-lg bg-muted/10 p-3 text-xs">
              <h4 className="font-semibold text-muted text-[11px] uppercase tracking-wide mb-1">结算规则</h4>
              {resolutionSource && (
                <div><span className="text-muted">数据来源：</span><span>{resolutionSource}</span></div>
              )}
              {resolutionRule && (
                <div><span className="text-muted">判定规则：</span><span>{resolutionRule}</span></div>
              )}
              {edgeCase && (
                <div><span className="text-muted">边界情况：</span><span>{edgeCase}</span></div>
              )}
            </div>
          )}
          <div className="rounded-lg bg-muted/10 p-3 text-sm">
            <span className="text-muted">您的余额：</span> <span className="font-medium">{userBalance.toFixed(4)} CORN</span>
          </div>

          <div className="border-t border-border pt-4">
            <h3 className="font-semibold text-sm mb-2">价格走势</h3>
            {priceLoading ? (
              <Skeleton className="h-[200px] w-full" />
            ) : (
              <PriceChart data={priceHistory} />
            )}
          </div>

          <div className="border-t border-border pt-4">
            <MarketTimeline marketId={marketId} status={status} result={result} deadline={Number(deadline)} />
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
                isPending={isApprovePending || isBetPending}
                onBet={handleBet}
                onApprove={handleApprove}
              />
            </div>
          )}

          {isResolved && address && hasShares && (
            <div className="border-t border-border pt-4">
              <Button className="w-full" disabled={isClaimPending} onClick={handleClaim}>
                {isClaimPending ? <><Loader2 className="h-4 w-4 animate-spin" /> 确认中...</> : '领取奖励'}
              </Button>
            </div>
          )}

          {isOpen && canResolve && deadlinePassed && (
            <div className="space-y-3 border-t border-border pt-4">
              <h3 className="font-semibold">结算市场</h3>
              {settle.status === 'ok' ? (
                <div className="space-y-2 rounded-lg bg-muted/10 p-3 text-sm">
                  <p className="text-green-600">已自动广播：{settle.txHash}</p>
                  <a
                    href={`${EXPLORER_URL}/tx/${settle.txHash}`}
                    target="_blank"
                    rel="noreferrer"
                    className="inline-flex items-center gap-1 text-primary underline"
                  >
                    在区块浏览器查看
                    <svg className="h-3 w-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M7 17L17 7M7 7h10v10"/></svg>
                  </a>
                </div>
              ) : settle.status === 'pending' ? (
                <p className="flex items-center gap-2 text-sm text-muted">
                  <Loader2 className="h-4 w-4 animate-spin" /> 正在自动广播结算交易...
                </p>
              ) : settle.status === 'manual' ? (
                <div className="space-y-2">
                  {settle.error && <p className="text-xs text-amber-600">自动广播失败：{settle.error}</p>}
                  <p className="text-sm text-muted">自动广播不可用，请选择结算结果并手动广播。</p>
                  <div className="flex gap-2">
                    <Button variant="outline" className="flex-1" onClick={() => setManual(buildManualSettle(true))}>结算 YES 胜</Button>
                    <Button variant="outline" className="flex-1" onClick={() => setManual(buildManualSettle(false))}>结算 NO 胜</Button>
                  </div>
                  {manual && (
                    <div className="space-y-2 rounded-lg bg-muted/10 p-3">
                      <textarea readOnly value={manual.payload} rows={6}
                        className="w-full resize-y rounded border bg-background p-2 font-mono text-xs" />
                      <div className="flex flex-wrap gap-2">
                        <Button size="sm" onClick={() => copyText(manual.payload, '交易数据')}>复制交易数据(JSON)</Button>
                        <Button size="sm" variant="outline" onClick={() => copyText(manual.castCmd, 'cast 命令')}>复制 cast 命令</Button>
                      </div>
                    </div>
                  )}
                </div>
              ) : (
                <div className="space-y-3">
                  <p className="text-sm text-muted">截止时间已过，请选择获胜结果。优先服务端自动广播，失败可手动广播。</p>
                  <div className="flex gap-2">
                    <Button className="flex-1" variant="outline" onClick={() => handleResolve(true)}>结算 YES 胜</Button>
                    <Button className="flex-1" variant="outline" onClick={() => handleResolve(false)}>结算 NO 胜</Button>
                  </div>
                </div>
              )}
            </div>
          )}

          {isResolved && address && onRaiseDispute && (
            <div className="border-t border-border pt-4">
              <Button
                variant="outline"
                className="w-full border-amber-300 text-amber-700 hover:bg-amber-50"
                onClick={() => onRaiseDispute(marketId)}
              >
                <AlertTriangle className="mr-2 h-4 w-4" /> 发起争议
              </Button>
            </div>
          )}

          {disputes.length > 0 && (
            <div className="border-t border-border pt-4 space-y-2">
              <h3 className="font-semibold text-sm">关联争议</h3>
              {disputes.map(d => {
                const total = d.votesFor + d.votesAgainst
                const yesP = total > 0 ? (d.votesFor / total) * 100 : 50
                const stateLabel = d.state === 0 ? '进行中' : d.state === 1 ? '已通过' : '已驳回'
                const stateVariant = d.state === 1 ? 'success' : d.state === 2 ? 'destructive' : 'default' as const
                return (
                  <div key={d.id.toString()} className="rounded-lg bg-muted/10 px-3 py-2.5 text-sm space-y-2">
                    <div className="flex items-center justify-between gap-2">
                      <div className="flex items-center gap-2 min-w-0">
                        <span className="font-mono text-muted">#{d.id.toString()}</span>
                        <Badge variant={stateVariant} className="text-xs shrink-0">{stateLabel}</Badge>
                        <span className="text-muted shrink-0">{d.disputeType === 0 ? '预言机结果' : '市场内容'}</span>
                      </div>
                      <span className="text-xs text-muted shrink-0">{formatEther(d.deposit)} CORN</span>
                    </div>
                    <p className="text-muted text-xs truncate">{d.reason}</p>
                    {total > 0 && (
                      <div className="flex items-center gap-2 text-xs">
                        <span className="text-yes font-medium">{d.votesFor} 赞成</span>
                        <div className="flex-1 h-1.5 overflow-hidden rounded-full bg-muted/30" role="progressbar" aria-valuenow={yesP} aria-valuemin={0} aria-valuemax={100} aria-label={`${d.votesFor} 赞成 / ${d.votesAgainst} 反对`}>
                          <div className="flex h-full">
                            <div className="bg-yes" style={{ width: `${yesP}%` }} />
                            <div className="bg-no" style={{ width: `${100 - yesP}%` }} />
                          </div>
                        </div>
                        <span className="text-no font-medium">{d.votesAgainst} 反对</span>
                      </div>
                    )}
                  </div>
                )
              })}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
