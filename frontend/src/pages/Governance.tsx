import { useEffect, useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { useAccount, usePublicClient, useReadContract } from 'wagmi'
import { formatEther, encodeFunctionData } from 'viem'
import {
  TOKEN_HOUSE_ADDRESS, tokenHouseABI,
  GOV_CORN_TOKEN_ADDRESS, govCrownTokenABI,
} from '../contracts/abi'
import { getLogsChunked } from '../lib/getLogsChunked'
import {
  useProposalState, useProposalVotes, useProposalProposer,
  useProposalDeadline, useProposalSnapshot, useCastVote,
  usePropose, useProposalThreshold,
} from '../hooks/useGovernance'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { ArrowLeft, Loader2 } from 'lucide-react'
import { useToast } from '../components/Toast'

const STATE_LABEL: Record<string, string> = {
  Pending: '待定', Active: '进行中', Canceled: '已取消', Defeated: '未通过',
  Succeeded: '已通过', Queued: '已排队', Expired: '已过期', Executed: '已执行',
}

const STATE_VARIANT: Record<string, 'default' | 'secondary' | 'success' | 'destructive'> = {
  Pending: 'secondary', Active: 'default', Succeeded: 'success',
  Queued: 'success', Executed: 'success', Defeated: 'destructive',
  Canceled: 'secondary', Expired: 'secondary',
}

function ProposalDetail({ id, onBack }: { id: bigint; onBack: () => void }) {
  const { toast } = useToast()
  const { data: state } = useProposalState(id)
  const { data: votes } = useProposalVotes(id)
  const { data: proposer } = useProposalProposer(id)
  const { data: deadline } = useProposalDeadline(id)
  const { data: snapshot } = useProposalSnapshot(id)
  const { writeContract, isPending: isVotePending } = useCastVote()
  const { address } = useAccount()
  const queryClient = useQueryClient()

  const { data: userVotes } = useReadContract({
    address: GOV_CORN_TOKEN_ADDRESS,
    abi: govCrownTokenABI,
    functionName: 'getVotes',
    args: address ? [address] : undefined,
  })

  const against = votes ? (votes as [bigint, bigint, bigint])[0] : undefined
  const forVotes = votes ? (votes as [bigint, bigint, bigint])[1] : undefined
  const abstain = votes ? (votes as [bigint, bigint, bigint])[2] : undefined

  return (
    <div className="space-y-4">
      <Button variant="ghost" size="sm" onClick={onBack} className="text-muted">
        <ArrowLeft className="mr-2 h-4 w-4" /> 返回
      </Button>
      <Card>
        <CardHeader>
          <div className="flex items-start justify-between gap-2">
            <CardTitle className="text-xl">提案 #{id.toString()}</CardTitle>
            <Badge variant={STATE_VARIANT[state as string || ''] || 'secondary'}>{state as string || '—'}</Badge>
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-1 gap-4 text-sm sm:grid-cols-2">
            <div><span className="text-muted">提案人：</span><br /><code className="break-all font-mono">{proposer as string || '—'}</code></div>
            <div><span className="text-muted">快照区块：</span><br />{snapshot?.toString() || '—'}</div>
            <div><span className="text-muted">截止区块：</span><br />{deadline?.toString() || '—'}</div>
          </div>
          <div className="grid grid-cols-1 gap-4 text-sm sm:grid-cols-3">
            <div><span className="text-yes font-medium">赞成：</span><br />{forVotes !== undefined ? Number(formatEther(forVotes)).toFixed(4) : '—'} govCORN</div>
            <div><span className="text-no font-medium">反对：</span><br />{against !== undefined ? Number(formatEther(against)).toFixed(4) : '—'} govCORN</div>
            <div><span className="text-muted font-medium">弃权：</span><br />{abstain !== undefined ? Number(formatEther(abstain)).toFixed(4) : '—'} govCORN</div>
          </div>

          {state === 'Active' && address && (
            <div className="space-y-3 border-t border-border pt-4">
              <p className="text-sm text-muted">
                您的投票权： <span className="font-medium text-foreground">{userVotes ? formatEther(userVotes as bigint) : '0'} govCORN</span>
              </p>
              {userVotes !== undefined && (userVotes as bigint) > 0n && (
                <div className="flex gap-2">
                  <Button
                    variant="outline"
                    className="min-w-0 border-transparent bg-yes text-white hover:bg-yes/90"
                    disabled={isVotePending}
                    onClick={() => { toast('交易已提交，请等待确认...', 'info'); writeContract({
                      address: TOKEN_HOUSE_ADDRESS, abi: tokenHouseABI,
                      functionName: 'castVote',
                      args: [id, 1],
                    }, { onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['readContract'] }); toast('投票成功', 'success') }, onError: (e: any) => toast('交易失败: ' + (e.shortMessage ?? e.message), 'error') }) }}
                  >
                    {isVotePending ? <><Loader2 className="h-4 w-4 animate-spin" /> 确认中...</> : '赞成'}
                  </Button>
                  <Button
                    variant="outline"
                    className="min-w-0 border-transparent bg-no text-white hover:bg-no/90"
                    disabled={isVotePending}
                    onClick={() => { toast('交易已提交，请等待确认...', 'info'); writeContract({
                      address: TOKEN_HOUSE_ADDRESS, abi: tokenHouseABI,
                      functionName: 'castVote',
                      args: [id, 0],
                    }, { onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['readContract'] }); toast('投票成功', 'success') }, onError: (e: any) => toast('交易失败: ' + (e.shortMessage ?? e.message), 'error') }) }}
                  >
                    {isVotePending ? <><Loader2 className="h-4 w-4 animate-spin" /> 确认中...</> : '反对'}
                  </Button>
                  <Button
                    variant="outline"
                    className="min-w-0 border-transparent bg-muted text-white hover:bg-muted/90"
                    disabled={isVotePending}
                    onClick={() => { toast('交易已提交，请等待确认...', 'info'); writeContract({
                      address: TOKEN_HOUSE_ADDRESS, abi: tokenHouseABI,
                      functionName: 'castVote',
                      args: [id, 2],
                    }, { onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['readContract'] }); toast('投票成功', 'success') }, onError: (e: any) => toast('交易失败: ' + (e.shortMessage ?? e.message), 'error') }) }}
                  >
                    {isVotePending ? <><Loader2 className="h-4 w-4 animate-spin" /> 确认中...</> : '弃权'}
                  </Button>
                </div>
              )}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}

function CreateProposal({ onCreated }: { onCreated: () => void }) {
  const { toast } = useToast()
  const { address } = useAccount()
  const [target, setTarget] = useState('')
  const [value, setValue] = useState('0')
  const [funcSig, setFuncSig] = useState('')
  const [argsJson, setArgsJson] = useState('[]')
  const [description, setDescription] = useState('')
  const [error, setError] = useState<string | null>(null)
  const { writeContract, isPending: isProposePending } = usePropose()

  const { data: threshold } = useProposalThreshold()
  const { data: userVotes } = useReadContract({
    address: GOV_CORN_TOKEN_ADDRESS,
    abi: govCrownTokenABI,
    functionName: 'getVotes',
    args: address ? [address] : undefined,
  })

  const canPropose = threshold !== undefined && userVotes !== undefined && (userVotes as bigint) >= (threshold as bigint)
  const validAddress = /^0x[a-fA-F0-9]{40}$/.test(target)

  const handleSubmit = () => {
    setError(null)
    try {
      const abi = funcSig ? [`function ${funcSig}`] as const : ['function ()'] as const
      const fnName = funcSig ? funcSig.split('(')[0] : ''
      const args = funcSig ? JSON.parse(argsJson) : []
      const calldata = funcSig
        ? encodeFunctionData({ abi, functionName: fnName, args })
        : '0x'

      toast('交易已提交，请等待确认...', 'info')
      writeContract({
        address: TOKEN_HOUSE_ADDRESS,
        abi: tokenHouseABI,
        functionName: 'propose',
        args: [
          [target as `0x${string}`],
          [BigInt(value || '0')],
          [calldata as `0x${string}`],
          description,
        ],
      }, {
        onSuccess: () => { setTarget(''); setValue('0'); setFuncSig(''); setArgsJson('[]'); setDescription(''); onCreated(); toast('交易成功', 'success') },
        onError: (e: any) => toast('交易失败: ' + (e.shortMessage ?? e.message), 'error'),
      })
    } catch (e: any) {
      setError(e.message || 'Failed to build calldata')
    }
  }

  return (
    <div className="space-y-4">
      <div className="space-y-1 rounded-lg bg-muted/10 p-3 text-sm">
        <p>投票权： <span className="font-medium">{userVotes ? formatEther(userVotes as bigint) : '0'} govCORN</span></p>
        <p>所需门槛： <span className="font-medium">{threshold ? formatEther(threshold as bigint) : '-'} govCORN</span> <span className="text-muted">（总供应量的 1%）</span></p>
      </div>
      {!canPropose && threshold !== undefined && (
        <p className="text-sm text-no">投票权不足，无法发起提案。请委托或获取更多 govCORN。</p>
      )}
      <div className="space-y-2">
        <Label htmlFor="proposal-target">目标地址</Label>
        <Input id="proposal-target" value={target} onChange={e => setTarget(e.target.value)} placeholder="0x..." className="font-mono" />
      </div>
      <div className="space-y-2">
        <Label htmlFor="proposal-value">ETH 数值（wei）</Label>
        <Input id="proposal-value" value={value} onChange={e => setValue(e.target.value)} placeholder="0" />
      </div>
      <div className="space-y-2">
        <Label htmlFor="proposal-funcsig">函数签名（可选）</Label>
        <Input id="proposal-funcsig" value={funcSig} onChange={e => setFuncSig(e.target.value)} placeholder="transfer(address,uint256)" />
      </div>
      {funcSig && (
        <div className="space-y-2">
          <Label htmlFor="proposal-args">参数（JSON 数组）</Label>
          <Input id="proposal-args" value={argsJson} onChange={e => setArgsJson(e.target.value)} placeholder='["0x1234...", 1000000000000000000]' className="font-mono" />
        </div>
      )}
      <div className="space-y-2">
        <Label htmlFor="proposal-desc">描述</Label>
        <textarea
          id="proposal-desc"
          value={description}
          onChange={e => setDescription(e.target.value)}
          rows={3}
          className="flex min-h-[80px] w-full rounded-md border border-border bg-card px-3 py-2 text-sm placeholder:text-muted focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
        />
      </div>
      {error && <p className="text-sm text-no">{error}</p>}
      <Button className="w-full" disabled={!canPropose || !validAddress || !description || isProposePending} onClick={handleSubmit}>
        {isProposePending ? <><Loader2 className="h-4 w-4 animate-spin" /> 确认中...</> : '提交提案'}
      </Button>
    </div>
  )
}

export function Governance() {
  const { address } = useAccount()
  const publicClient = usePublicClient()
  const [proposals, setProposals] = useState<Array<{ id: bigint; description: string }>>([])
  const [loading, setLoading] = useState(true)
  const [loadError, setLoadError] = useState<string | null>(null)
  const [selectedId, setSelectedId] = useState<bigint | null>(null)
  const [showForm, setShowForm] = useState(false)
  const [refreshKey, setRefreshKey] = useState(0)

  useEffect(() => {
    if (!publicClient) return
    setLoading(true)
    let cancelled = false
    ;(async () => {
      if (!TOKEN_HOUSE_ADDRESS.startsWith('0x') || TOKEN_HOUSE_ADDRESS.length < 42) {
        if (!cancelled) setLoading(false)
        return
      }
      try {
        const logs = await getLogsChunked(publicClient, {
          address: TOKEN_HOUSE_ADDRESS,
          event: {
            type: 'event',
            name: 'ProposalCreated',
            inputs: [
              { type: 'uint256', name: 'proposalId', indexed: true },
              { type: 'address', name: 'proposer', indexed: true },
              { type: 'address[]', name: 'targets', indexed: false },
              { type: 'uint256[]', name: 'values', indexed: false },
              { type: 'string[]', name: 'signatures', indexed: false },
              { type: 'bytes[]', name: 'calldatas', indexed: false },
              { type: 'uint256', name: 'voteStart', indexed: false },
              { type: 'uint256', name: 'voteEnd', indexed: false },
              { type: 'string', name: 'description', indexed: false },
            ],
          },
          maxBlocks: 20000n,
        })
        if (!cancelled) {
          setProposals((logs as any[]).map(l => ({
            id: (l.args as any).proposalId as bigint,
            description: (l.args as any).description as string,
          })).reverse())
          setLoading(false)
        }
      } catch (e) {
        if (!cancelled) { setLoading(false); setLoadError('提案加载失败，请检查网络后重试。') }
      }
    })()
    return () => { cancelled = true }
  }, [publicClient?.uid, refreshKey])

  if (selectedId !== null) {
    return <ProposalDetail id={selectedId} onBack={() => setSelectedId(null)} />
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="text-xl font-bold">治理</h2>
        {address && (
          <Button variant={showForm ? 'outline' : 'default'} onClick={() => setShowForm(!showForm)}>
            {showForm ? '取消' : '创建提案'}
          </Button>
        )}
      </div>
      <Dialog open={showForm} onOpenChange={setShowForm}>
        <DialogContent className="max-h-[90vh] max-w-xl overflow-y-auto">
          <DialogHeader>
            <DialogTitle>创建提案</DialogTitle>
            <DialogDescription>提交链上治理提案。需要 govCORN 投票权达到门槛以上。</DialogDescription>
          </DialogHeader>
          <CreateProposal onCreated={() => { setShowForm(false); setRefreshKey(k => k + 1) }} />
        </DialogContent>
      </Dialog>
      {loading ? <p className="text-muted">加载提案中...</p> : loadError ? <p className="text-no">{loadError}</p> : proposals.length === 0 ? <p className="text-muted">暂无提案。</p> : (
        <div className="space-y-3">
          {proposals.map(p => (
            <ProposalRow key={p.id.toString()} proposal={p} onSelect={() => setSelectedId(p.id)} />
          ))}
        </div>
      )}
    </div>
  )
}

function ProposalRow({ proposal: p, onSelect }: { proposal: { id: bigint; description: string }; onSelect: () => void }) {
  const { data: state } = useProposalState(p.id)
  const desc = p.description.length > 100 ? p.description.slice(0, 100) + '…' : p.description
  return (
    <Card>
      <CardContent className="flex items-center justify-between gap-4 p-4">
        <div className="min-w-0">
          <div className="flex items-center gap-2">
            <span className="font-mono text-sm font-semibold">#{p.id.toString()}</span>
            <Badge variant={STATE_VARIANT[state as string || ''] || 'secondary'}>{STATE_LABEL[state as string || ''] || '—'}</Badge>
          </div>
          <p className="mt-1 truncate text-sm text-muted">{desc}</p>
        </div>
        <Button variant="outline" size="sm" onClick={onSelect}>查看</Button>
      </CardContent>
    </Card>
  )
}
