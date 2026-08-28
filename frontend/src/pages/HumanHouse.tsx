import { useEffect, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import { useAccount, usePublicClient, useReadContract, useWriteContract } from 'wagmi'
import { formatEther } from 'viem'
import {
  CORN_TOKEN_ADDRESS, cornTokenABI,
  HUMAN_HOUSE_ADDRESS, humanHouseABI,
} from '../contracts/abi'
import {
  useDispute, useDisputeDeposit, useRaiseDispute, useVote, useExecuteDispute,
  fetchAllDisputes, fetchVoteLogs, fetchDisputeExecutedLogs,
} from '../hooks/useHumanHouse'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { ArrowLeft, Loader2, Circle, CheckCircle, Gavel } from 'lucide-react'
import { useToast } from '../components/Toast'

const DISPUTE_TYPE: Record<number, string> = { 0: '预言机结果', 1: '市场内容' }
const DISPUTE_STATE: Record<number, string> = { 0: '进行中', 1: '已通过', 2: '已驳回' }
const STATE_VARIANT: Record<number, 'default' | 'secondary' | 'success' | 'destructive'> = {
  0: 'default',
  1: 'success',
  2: 'destructive',
}

const MOCK_ROOT = 0n
const MOCK_NULLIFIER_HASH = 0n
const MOCK_PROOF = [0n, 0n, 0n, 0n, 0n, 0n, 0n, 0n] as [bigint, bigint, bigint, bigint, bigint, bigint, bigint, bigint]

interface DisputeInfo {
  id: bigint
  marketId: bigint
  disputeType: number
  reason: string
}

interface TimelineEvent {
  type: 'created' | 'vote' | 'executed'
  timestamp: bigint
  detail: string
  support?: boolean
  outcome?: number
}

function DisputeDetail({ id, onBack, onNavigateToMarket }: { id: bigint; onBack: () => void; onNavigateToMarket?: (id: number) => void }) {
  const { toast } = useToast()
  const { address } = useAccount()
  const publicClient = usePublicClient()
  const { data: dispute } = useDispute(id)
  const { writeContract: writeVote, isPending: isVotePending } = useVote()
  const { writeContract: writeExecute, isPending: isExecutePending } = useExecuteDispute()
  const queryClient = useQueryClient()
  const [timeline, setTimeline] = useState<TimelineEvent[]>([])
  const [timelineLoading, setTimelineLoading] = useState(true)

  useEffect(() => {
    if (!publicClient) return
    setTimelineLoading(true)
    Promise.all([
      fetchAllDisputes(publicClient),
      fetchVoteLogs(publicClient, id),
      fetchDisputeExecutedLogs(publicClient),
    ]).then(([createdLogs, voteLogs, executedLogs]) => {
      const events: TimelineEvent[] = []
      createdLogs
        .filter((l: any) => l.id === id)
        .forEach((l: any) => {
          events.push({ type: 'created', timestamp: l.blockTimestamp ?? l.timestamp ?? 0n, detail: `发起争议 — ${l.reason}` })
        })
      voteLogs
        .filter((l: any) => (l.args.disputeId as bigint) === id)
        .forEach((l: any) => {
          events.push({ type: 'vote', timestamp: l.timestamp ?? 0n, detail: l.args.support ? '投赞成票' : '投反对票', support: l.args.support })
        })
      executedLogs
        .filter((l: any) => (l.args.disputeId as bigint) === id)
        .forEach((l: any) => {
          const outcomeLabel = Number(l.args.outcome) === 1 ? '争议通过' : '争议驳回'
          events.push({ type: 'executed', timestamp: l.timestamp ?? 0n, detail: `执行裁决 — ${outcomeLabel}`, outcome: Number(l.args.outcome) })
        })
      events.sort((a, b) => Number(a.timestamp - b.timestamp))
      setTimeline(events)
      setTimelineLoading(false)
    }).catch(() => setTimelineLoading(false))
  }, [publicClient, id])

  if (!dispute) return <p className="text-muted">加载争议 #{id.toString()}...</p>

  const [marketId, disputeType, state, initiator, deposit, deadline, reason, votesFor, votesAgainst] = dispute as any
  const isActive = Number(state) === 0
  const isExpired = Date.now() / 1000 > Number(deadline)
  const totalVotes = Number(votesFor) + Number(votesAgainst)
  const yesPercent = totalVotes > 0 ? (Number(votesFor) / totalVotes) * 100 : 50

  const TIMELINE_ICONS: Record<string, typeof Circle> = { created: Circle, vote: CheckCircle, executed: Gavel }
  const TIMELINE_COLORS: Record<string, string> = { created: 'text-primary', vote: 'text-blue-500', executed: 'text-amber-500' }

  return (
    <div className="space-y-4">
      <Button variant="ghost" size="sm" onClick={onBack} className="text-muted">
        <ArrowLeft className="mr-2 h-4 w-4" /> 返回
      </Button>

      {/* Basic Info */}
      <Card>
        <CardHeader>
          <div className="flex items-start justify-between gap-2">
            <CardTitle className="text-xl">争议 #{id.toString()}</CardTitle>
            <Badge variant={STATE_VARIANT[Number(state)] || 'secondary'}>{DISPUTE_STATE[Number(state)] || '未知'}</Badge>
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-1 gap-4 text-sm sm:grid-cols-2">
            <div><span className="text-muted">市场 ID：</span><br />
              {onNavigateToMarket ? (
                <button onClick={() => onNavigateToMarket(Number(marketId))} className="font-mono text-primary underline underline-offset-2 hover:text-primary/80">
                  #{marketId.toString()}
                </button>
              ) : (
                <span className="font-mono">#{marketId.toString()}</span>
              )}
            </div>
            <div><span className="text-muted">类型：</span><br />{DISPUTE_TYPE[disputeType] || '未知'}</div>
            <div><span className="text-muted">发起人：</span><br /><code className="break-all font-mono text-xs">{initiator}</code></div>
            <div><span className="text-muted">保证金：</span><br />{formatEther(deposit)} CORN</div>
            <div><span className="text-muted">截止时间：</span><br />{new Date(Number(deadline) * 1000).toLocaleString()}</div>
          </div>
          <div className="text-sm"><span className="text-muted">原因：</span><br />{reason}</div>

          {/* Vote Progress Bar */}
          <div className="space-y-2">
            <div className="flex items-center justify-between text-sm">
              <span className="text-yes font-medium">赞成 {Number(votesFor)}</span>
              <span className="text-muted">{totalVotes} 票</span>
              <span className="text-no font-medium">反对 {Number(votesAgainst)}</span>
            </div>
            <div className="h-3 w-full overflow-hidden rounded-full bg-muted/30" role="progressbar" aria-valuenow={yesPercent} aria-valuemin={0} aria-valuemax={100} aria-label={`${Number(votesFor)} 赞成 / ${Number(votesAgainst)} 反对`}>
              <div className="flex h-full">
                <div className="bg-yes transition-all duration-500" style={{ width: `${yesPercent}%` }} />
                <div className="bg-no transition-all duration-500" style={{ width: `${100 - yesPercent}%` }} />
              </div>
            </div>
          </div>

          {/* Action Buttons */}
          {isActive && !isExpired && address && (
            <div className="space-y-3 border-t border-border pt-4">
              <div className="space-y-1">
                <p className="font-medium text-sm">World ID 验证（模拟）</p>
                <p className="text-xs text-muted">当前使用模拟证明，真正的 World ID 集成即将上线。</p>
              </div>
              <div className="flex gap-2">
                <Button
                  variant="outline"
                  className="min-w-0 border-transparent bg-yes text-white hover:bg-yes/90"
                  disabled={isVotePending}
                  onClick={() => { toast('交易已提交，请等待确认...', 'info'); writeVote({
                    address: HUMAN_HOUSE_ADDRESS, abi: humanHouseABI, functionName: 'vote',
                    args: [id, true, MOCK_ROOT, MOCK_NULLIFIER_HASH, MOCK_PROOF],
                  }, { onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['readContract'] }); toast('投票成功', 'success') } }) }}
                >
                  {isVotePending ? <><Loader2 className="h-4 w-4 animate-spin" /> 确认中...</> : '投赞成票'}
                </Button>
                <Button
                  variant="outline"
                  className="min-w-0 border-transparent bg-no text-white hover:bg-no/90"
                  disabled={isVotePending}
                  onClick={() => { toast('交易已提交，请等待确认...', 'info'); writeVote({
                    address: HUMAN_HOUSE_ADDRESS, abi: humanHouseABI, functionName: 'vote',
                    args: [id, false, MOCK_ROOT, MOCK_NULLIFIER_HASH, MOCK_PROOF],
                  }, { onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['readContract'] }); toast('投票成功', 'success') } }) }}
                >
                  {isVotePending ? <><Loader2 className="h-4 w-4 animate-spin" /> 确认中...</> : '投反对票'}
                </Button>
              </div>
            </div>
          )}

          {isActive && isExpired && address && (
            <div className="border-t border-border pt-4">
              <Button
                variant="outline"
                className="border-transparent bg-amber-500 text-white hover:bg-amber-600"
                disabled={isExecutePending}
                onClick={() => { toast('交易已提交，请等待确认...', 'info'); writeExecute({
                  address: HUMAN_HOUSE_ADDRESS, abi: humanHouseABI, functionName: 'executeDispute', args: [id],
                }, { onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['readContract'] }); toast('争议裁决已执行', 'success') } }) }}
              >
                {isExecutePending ? <><Loader2 className="h-4 w-4 animate-spin" /> 确认中...</> : '执行争议裁决'}
              </Button>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Activity Timeline */}
      <Card>
        <CardHeader>
          <CardTitle className="text-lg">活动记录</CardTitle>
        </CardHeader>
        <CardContent>
          {timelineLoading ? (
            <p className="text-sm text-muted">加载活动记录...</p>
          ) : timeline.length === 0 ? (
            <p className="text-sm text-muted">暂无活动记录。</p>
          ) : (
            <div className="relative ml-3 border-l-2 border-muted/30 pl-6 space-y-5">
              {timeline.map((evt, i) => {
                const Icon = TIMELINE_ICONS[evt.type] || Circle
                const color = TIMELINE_COLORS[evt.type] || 'text-muted'
                const ts = Number(evt.timestamp) > 0 ? new Date(Number(evt.timestamp) * 1000).toLocaleString() : '—'
                return (
                  <div key={i} className="relative">
                    <div className={`absolute -left-[31px] top-0.5 ${color}`}>
                      <Icon className="h-4 w-4" />
                    </div>
                    <div className="text-sm">
                      <div className="flex items-center gap-2">
                        <span className="font-medium">{evt.detail}</span>
                        {evt.type === 'vote' && evt.support !== undefined && (
                          <Badge variant={evt.support ? 'success' : 'destructive'} className="text-xs">
                            {evt.support ? '赞成' : '反对'}
                          </Badge>
                        )}
                        {evt.type === 'executed' && (
                          <Badge variant={evt.outcome === 1 ? 'success' : 'destructive'} className="text-xs">
                            {evt.outcome === 1 ? '通过' : '驳回'}
                          </Badge>
                        )}
                      </div>
                      <span className="text-xs text-muted">{ts}</span>
                    </div>
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

function RaiseDispute({ onCreated, initialMarketId }: { onCreated: () => void; initialMarketId?: number | null }) {
  const { toast } = useToast()
  const { address } = useAccount()
  const [marketId, setMarketId] = useState(initialMarketId != null ? String(initialMarketId) : '')
  const [disputeType, setDisputeType] = useState('0')
  const [reason, setReason] = useState('')
  const { writeContract, isPending: isDisputePending } = useRaiseDispute()
  const { writeContract: writeApprove, isPending: isApprovePending } = useWriteContract()

  const { data: disputeDeposit } = useDisputeDeposit()
  const deposit = (disputeDeposit as bigint | undefined) ?? 0n
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: CORN_TOKEN_ADDRESS,
    abi: cornTokenABI,
    functionName: 'allowance',
    args: address ? [address, HUMAN_HOUSE_ADDRESS] : undefined,
  })

  const needsApprove = deposit > (allowance as bigint)
  const validMarketId = /^\d+$/.test(marketId)

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-lg">发起争议</CardTitle>
        {deposit > 0n && <CardDescription>所需保证金： {formatEther(deposit)} CORN</CardDescription>}
      </CardHeader>
      <CardContent className="space-y-3">
        <div className="space-y-2">
          <Label htmlFor="dispute-market-id">市场 ID</Label>
          <Input id="dispute-market-id" value={marketId} onChange={e => setMarketId(e.target.value)} placeholder="Market ID" />
        </div>
        <div className="space-y-2">
          <Label htmlFor="dispute-type">类型</Label>
          <Select value={disputeType} onValueChange={setDisputeType}>
            <SelectTrigger id="dispute-type">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="0">预言机结果</SelectItem>
              <SelectItem value="1">市场内容</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <div className="space-y-2">
          <Label htmlFor="dispute-reason">原因</Label>
          <Input id="dispute-reason" value={reason} onChange={e => setReason(e.target.value)} placeholder="该结果为何有误" />
        </div>
        <div className="flex gap-2 pt-2">
          {needsApprove && (
            <Button
              variant="outline"
              disabled={isApprovePending}
              onClick={() => { toast('交易已提交，请等待确认...', 'info'); writeApprove({
                address: CORN_TOKEN_ADDRESS,
                abi: cornTokenABI,
                functionName: 'approve',
                args: [HUMAN_HOUSE_ADDRESS, deposit],
              }, { onSuccess: () => { refetchAllowance(); toast('交易成功', 'success') } }) }}
            >
              {isApprovePending ? <><Loader2 className="h-4 w-4 animate-spin" /> 确认中...</> : '授权 CORN'}
            </Button>
          )}
          <Button
            disabled={!validMarketId || !reason || !!needsApprove || isDisputePending}
            onClick={() => { toast('交易已提交，请等待确认...', 'info'); writeContract({
              address: HUMAN_HOUSE_ADDRESS,
              abi: humanHouseABI,
              functionName: 'raiseDispute',
              args: [BigInt(marketId), Number(disputeType), reason],
            }, { onSuccess: () => { setMarketId(''); setReason(''); onCreated(); toast('交易成功', 'success') } }) }}
          >
            {isDisputePending ? <><Loader2 className="h-4 w-4 animate-spin" /> 确认中...</> : '发起争议'}
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}

function DisputeRow({ dispute: d, onSelect, onNavigateToMarket }: { dispute: DisputeInfo; onSelect: () => void; onNavigateToMarket?: (id: number) => void }) {
  const { data: dispute } = useDispute(d.id)
  const state = dispute ? (dispute as any)[2] : undefined
  const deadline = dispute ? (dispute as any)[5] : undefined
  const votesFor = dispute ? Number((dispute as any)[7]) : 0
  const votesAgainst = dispute ? Number((dispute as any)[8]) : 0
  const deposit = dispute ? (dispute as any)[4] as bigint : 0n
  const totalVotes = votesFor + votesAgainst
  const yesPercent = totalVotes > 0 ? (votesFor / totalVotes) * 100 : 50

  return (
    <Card className="hover:shadow-md transition-shadow">
      <CardContent className="p-4 space-y-3">
        <div className="flex items-center justify-between gap-4">
          <div className="min-w-0 space-y-1">
            <div className="flex items-center gap-2">
              <span className="font-mono text-sm font-semibold">#{d.id.toString()}</span>
              <Badge variant={STATE_VARIANT[Number(state)] || 'secondary'}>{DISPUTE_STATE[Number(state)] || '—'}</Badge>
            </div>
            <div className="flex flex-wrap gap-x-4 gap-y-1 text-sm text-muted">
              <span>市场：{onNavigateToMarket ? (
                <button onClick={() => onNavigateToMarket(Number(d.marketId))} className="font-mono text-primary underline underline-offset-2 hover:text-primary/80">
                  #{d.marketId.toString()}
                </button>
              ) : (
                <span className="font-mono">#{d.marketId.toString()}</span>
              )}</span>
              <span>{DISPUTE_TYPE[d.disputeType]}</span>
              <span>{deadline ? new Date(Number(deadline) * 1000).toLocaleDateString() : '—'}</span>
            </div>
            <p className="text-sm text-muted truncate">{d.reason.length > 50 ? d.reason.slice(0, 50) + '...' : d.reason}</p>
          </div>
          <Button variant="outline" size="sm" onClick={onSelect}>查看</Button>
        </div>
        {/* Mini vote bar */}
        <div className="flex items-center gap-3 text-xs text-muted">
          <span className="text-yes font-medium">{votesFor} 赞成</span>
          <div className="flex-1 h-1.5 overflow-hidden rounded-full bg-muted/30">
            <div className="flex h-full">
              <div className="bg-yes" style={{ width: `${yesPercent}%` }} />
              <div className="bg-no" style={{ width: `${100 - yesPercent}%` }} />
            </div>
          </div>
          <span className="text-no font-medium">{votesAgainst} 反对</span>
          <span className="shrink-0">{formatEther(deposit)} CORN</span>
        </div>
      </CardContent>
    </Card>
  )
}

export function HumanHouse({ onNavigateToMarket }: { onNavigateToMarket?: (id: number) => void }) {
  const [searchParams] = useSearchParams()
  const initialMarketId = searchParams.get('marketId')
  const publicClient = usePublicClient()
  const [disputes, setDisputes] = useState<DisputeInfo[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [selectedId, setSelectedId] = useState<bigint | null>(null)
  const [refreshKey, setRefreshKey] = useState(0)

  useEffect(() => {
    if (!publicClient) return
    setLoading(true)
    setError(null)
    let cancelled = false
    fetchAllDisputes(publicClient).then((disputes: any[]) => {
      if (!cancelled) {
        setDisputes(disputes)
        setLoading(false)
      }
    }).catch((e) => {
      if (!cancelled) {
        console.error('Failed to fetch disputes:', e)
        setError('争议加载失败')
        setLoading(false)
      }
    })
    return () => { cancelled = true }
  }, [publicClient, refreshKey])

  if (selectedId !== null) {
    return <DisputeDetail id={selectedId} onBack={() => setSelectedId(null)} onNavigateToMarket={onNavigateToMarket} />
  }

  return (
    <div className="space-y-4">
      <h2 className="text-xl font-bold">HumanHouse 争议</h2>
      <RaiseDispute onCreated={() => setRefreshKey(k => k + 1)} initialMarketId={initialMarketId ? Number(initialMarketId) : null} />
      {loading ? <p className="text-muted">加载争议...</p> : error ? <p className="text-no">{error}</p> : disputes.length === 0 ? <p className="text-muted">暂无争议。</p> : (
        <div className="space-y-3">
          {disputes.map(d => (
            <DisputeRow key={d.id.toString()} dispute={d} onSelect={() => setSelectedId(d.id)} onNavigateToMarket={onNavigateToMarket} />
          ))}
        </div>
      )}
    </div>
  )
}
