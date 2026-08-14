import { useEffect, useState } from 'react'
import { useAccount, usePublicClient, useReadContract, useWriteContract } from 'wagmi'
import { formatEther } from 'viem'
import {
  CORN_TOKEN_ADDRESS, cornTokenABI,
  HUMAN_HOUSE_ADDRESS, humanHouseABI,
} from '../contracts/abi'
import {
  useDispute, useDisputeDeposit, useRaiseDispute, useVote, useExecuteDispute,
  fetchDisputeCreatedLogs,
} from '../hooks/useHumanHouse'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { ArrowLeft } from 'lucide-react'

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

function DisputeDetail({ id, onBack }: { id: bigint; onBack: () => void }) {
  const { address } = useAccount()
  const { data: dispute } = useDispute(id)
  const { writeContract: writeVote } = useVote()
  const { writeContract: writeExecute } = useExecuteDispute()

  if (!dispute) return <p className="text-muted">加载争议 #{id.toString()}...</p>

  const [marketId, disputeType, state, initiator, deposit, deadline, reason, votesFor, votesAgainst] = dispute as any
  const isActive = Number(state) === 0
  const isExpired = Date.now() / 1000 > Number(deadline)

  return (
    <div className="space-y-4">
      <Button variant="ghost" size="sm" onClick={onBack} className="text-muted">
        <ArrowLeft className="mr-2 h-4 w-4" /> Back
      </Button>
      <Card>
        <CardHeader>
          <div className="flex items-start justify-between gap-2">
            <CardTitle className="text-xl">争议 #{id.toString()}</CardTitle>
            <Badge variant={STATE_VARIANT[Number(state)] || 'secondary'}>{DISPUTE_STATE[Number(state)] || '未知'}</Badge>
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-1 gap-4 text-sm sm:grid-cols-2">
            <div><span className="text-muted">市场 ID：</span><br />{marketId.toString()}</div>
            <div><span className="text-muted">类型：</span><br />{DISPUTE_TYPE[disputeType] || '未知'}</div>
            <div><span className="text-muted">发起人：</span><br /><code className="break-all font-mono">{initiator}</code></div>
            <div><span className="text-muted">保证金：</span><br />{formatEther(deposit)} CORN</div>
            <div><span className="text-muted">截止时间：</span><br />{new Date(Number(deadline) * 1000).toLocaleString()}</div>
          </div>
          <div className="text-sm"><span className="text-muted">原因：</span><br />{reason}</div>
          <div className="grid grid-cols-2 gap-4 text-sm">
            <div><span className="text-yes font-medium">赞成：</span><br />{formatEther(votesFor)}</div>
            <div><span className="text-no font-medium">反对：</span><br />{formatEther(votesAgainst)}</div>
          </div>

          {isActive && !isExpired && address && (
            <div className="space-y-3 border-t border-border pt-4">
              <div className="space-y-1">
                <p className="font-medium">World ID 验证（模拟）</p>
                <p className="text-xs text-muted">当前使用模拟证明，真正的 World ID 集成即将上线。</p>
              </div>
              <div className="flex flex-wrap gap-2">
                <Button
                  variant="outline"
                  className="border-transparent bg-yes text-white hover:bg-yes/90"
                  onClick={() => writeVote({
                    address: HUMAN_HOUSE_ADDRESS,
                    abi: humanHouseABI,
                    functionName: 'vote',
                    args: [id, true, MOCK_ROOT, MOCK_NULLIFIER_HASH, MOCK_PROOF],
                  })}
                >
                  投赞成票
                </Button>
                <Button
                  variant="outline"
                  className="border-transparent bg-no text-white hover:bg-no/90"
                  onClick={() => writeVote({
                    address: HUMAN_HOUSE_ADDRESS,
                    abi: humanHouseABI,
                    functionName: 'vote',
                    args: [id, false, MOCK_ROOT, MOCK_NULLIFIER_HASH, MOCK_PROOF],
                  })}
                >
                  投反对票
                </Button>
              </div>
            </div>
          )}

          {isActive && isExpired && address && (
            <div className="border-t border-border pt-4">
              <Button
                variant="outline"
                className="border-transparent bg-amber-500 text-white hover:bg-amber-600"
                onClick={() => writeExecute({
                  address: HUMAN_HOUSE_ADDRESS,
                  abi: humanHouseABI,
                  functionName: 'executeDispute',
                  args: [id],
                })}
              >
                执行争议裁决
              </Button>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}

function RaiseDispute({ onCreated }: { onCreated: () => void }) {
  const { address } = useAccount()
  const [marketId, setMarketId] = useState('')
  const [disputeType, setDisputeType] = useState('0')
  const [reason, setReason] = useState('')
  const { writeContract } = useRaiseDispute()
  const { writeContract: writeApprove } = useWriteContract()

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
          <Label>市场 ID</Label>
          <Input value={marketId} onChange={e => setMarketId(e.target.value)} placeholder="Market ID" />
        </div>
        <div className="space-y-2">
          <Label>类型</Label>
          <Select value={disputeType} onValueChange={setDisputeType}>
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="0">预言机结果</SelectItem>
              <SelectItem value="1">市场内容</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <div className="space-y-2">
          <Label>原因</Label>
          <Input value={reason} onChange={e => setReason(e.target.value)} placeholder="该结果为何有误" />
        </div>
        <div className="flex flex-wrap gap-2 pt-2">
          {needsApprove && (
            <Button
              variant="outline"
              onClick={() => writeApprove({
                address: CORN_TOKEN_ADDRESS,
                abi: cornTokenABI,
                functionName: 'approve',
                args: [HUMAN_HOUSE_ADDRESS, deposit],
              }, { onSuccess: () => refetchAllowance() })}
            >
              授权 CORN
            </Button>
          )}
          <Button
            disabled={!validMarketId || !reason || !!needsApprove}
            onClick={() => writeContract({
              address: HUMAN_HOUSE_ADDRESS,
              abi: humanHouseABI,
              functionName: 'raiseDispute',
              args: [BigInt(marketId), Number(disputeType), reason],
            }, { onSuccess: () => { setMarketId(''); setReason(''); onCreated() } })}
          >
            发起争议
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}

function DisputeRow({ dispute: d, onSelect }: { dispute: DisputeInfo; onSelect: () => void }) {
  const { data: dispute } = useDispute(d.id)
  const state = dispute ? (dispute as any)[2] : undefined
  const deadline = dispute ? (dispute as any)[5] : undefined

  return (
    <Card>
      <CardContent className="flex items-center justify-between gap-4 p-4">
        <div className="min-w-0 space-y-1">
          <div className="flex items-center gap-2">
            <span className="font-mono text-sm font-semibold">#{d.id.toString()}</span>
            <Badge variant={STATE_VARIANT[Number(state)] || 'secondary'}>{DISPUTE_STATE[Number(state)] || '—'}</Badge>
          </div>
          <div className="flex flex-wrap gap-x-4 gap-y-1 text-sm text-muted">
            <span>市场： {d.marketId.toString()}</span>
            <span>{DISPUTE_TYPE[d.disputeType]}</span>
            <span>截止时间： {deadline ? new Date(Number(deadline) * 1000).toLocaleDateString() : '—'}</span>
            <span className="truncate">{d.reason.length > 40 ? d.reason.slice(0, 40) + '...' : d.reason}</span>
          </div>
        </div>
        <Button variant="outline" size="sm" onClick={onSelect}>查看</Button>
      </CardContent>
    </Card>
  )
}

export function HumanHouse() {
  const { address } = useAccount()
  const publicClient = usePublicClient()
  const [disputes, setDisputes] = useState<DisputeInfo[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [selectedId, setSelectedId] = useState<bigint | null>(null)

  useEffect(() => {
    if (!publicClient) return
    setLoading(true)
    setError(null)
    fetchDisputeCreatedLogs(publicClient).then((logs: any[]) => {
      setDisputes(logs.map(l => ({
        id: l.args.disputeId as bigint,
        marketId: l.args.marketId as bigint,
        disputeType: Number(l.args.disputeType),
        reason: l.args.reason as string,
      })).reverse())
      setLoading(false)
    }).catch((e) => {
      console.error('Failed to fetch disputes:', e)
      setError('争议加载失败')
      setLoading(false)
    })
  }, [publicClient])

  if (selectedId !== null) {
    return <DisputeDetail id={selectedId} onBack={() => setSelectedId(null)} />
  }

  return (
    <div className="space-y-4">
      <h2 className="text-xl font-bold">HumanHouse 争议</h2>
      <RaiseDispute onCreated={() => setLoading(true)} />
      {!address ? <p className="text-muted">连接钱包以查看争议。</p> : loading ? <p className="text-muted">加载争议s...</p> : error ? <p className="text-no">{error}</p> : disputes.length === 0 ? <p className="text-muted">暂无争议。</p> : (
        <div className="space-y-3">
          {disputes.map(d => (
            <DisputeRow key={d.id.toString()} dispute={d} onSelect={() => setSelectedId(d.id)} />
          ))}
        </div>
      )}
    </div>
  )
}
