import { useAccount, useChainId, useReadContract } from 'wagmi'
import { PREDICTION_MARKET_ADDRESS, predictionMarketABI } from '../contracts/abi'
import { CHAIN_ID, CHAIN_NAME } from '../config'
import { getAdminRole, isRightChain, type AdminRole } from '../lib/admin'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Skeleton } from '@/components/ui/skeleton'
import { WalletConnect } from '../components/WalletConnect'
import { useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { useWriteSetResolver } from '../hooks/useMarket'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Loader2 } from 'lucide-react'
import { useToast } from '../components/Toast'
import { isValidAddress } from '../lib/helpers'

const ROLE_LABEL: Record<AdminRole, string> = {
  owner: 'Owner',
  operator: 'Operator',
  none: '无权限',
  unconnected: '未连接',
  unknown: '读取中',
}

const ROLE_VARIANT: Record<AdminRole, 'default' | 'success' | 'secondary' | 'destructive'> = {
  owner: 'default',
  operator: 'success',
  none: 'destructive',
  unconnected: 'secondary',
  unknown: 'secondary',
}

function Copyable({ text, label }: { text: string; label: string }) {
  return (
    <div>
      <span className="text-muted">{label}</span>
      <button
        onClick={() => { navigator.clipboard.writeText(text).catch(() => {}) }}
        className="ml-2 inline-flex items-center gap-1 rounded bg-muted/10 px-1.5 py-0.5 font-mono text-xs transition-colors hover:bg-muted/20"
        title="点击复制"
      >
        {text.length > 24 ? `${text.slice(0, 10)}…${text.slice(-8)}` : text}
      </button>
    </div>
  )
}

export function Admin() {
  const { address } = useAccount()
  const connectedChainId = useChainId()
  const { data: owner } = useReadContract({
    address: PREDICTION_MARKET_ADDRESS,
    abi: predictionMarketABI,
    functionName: 'owner',
  })
  const { data: amIResolver } = useReadContract({
    address: PREDICTION_MARKET_ADDRESS,
    abi: predictionMarketABI,
    functionName: 'resolvers',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  })
  const { toast } = useToast()
  const queryClient = useQueryClient()
  const { writeContract: setResolver, isPending: isSetResolverPending } = useWriteSetResolver()
  const [addrInput, setAddrInput] = useState('')
  const validAddr = isValidAddress(addrInput.trim())
  const { data: targetIsResolver } = useReadContract({
    address: PREDICTION_MARKET_ADDRESS,
    abi: predictionMarketABI,
    functionName: 'resolvers',
    args: validAddr ? [addrInput.trim() as `0x${string}`] : undefined,
    query: { enabled: validAddr },
  })

  const role = getAdminRole({ address, owner: owner as string | undefined, isResolver: amIResolver === true })
  const onRightChain = isRightChain(connectedChainId, CHAIN_ID)

  const handleSetResolver = (authorized: boolean) => {
    const target = addrInput.trim() as `0x${string}`
    if (!validAddr || !onRightChain) return
    toast('交易已提交，请等待确认...', 'info')
    setResolver(
      {
        address: PREDICTION_MARKET_ADDRESS,
        abi: predictionMarketABI,
        functionName: 'setResolver',
        args: [target, authorized],
      },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: ['readContract'] })
          toast(authorized ? '已授权该地址为 Resolver' : '已撤销该地址的 Resolver 权限', 'info')
        },
        onError: (e: any) => toast('交易失败: ' + (e.shortMessage ?? e.message), 'error'),
      }
    )
  }

  if (!address) {
    return (
      <div className="space-y-4">
        <Card>
          <CardHeader><CardTitle>管理后台</CardTitle></CardHeader>
          <CardContent>
            <p className="text-muted">请先连接钱包。管理操作以钱包地址作为链上操作身份。</p>
            <div className="mt-4"><WalletConnect /></div>
          </CardContent>
        </Card>
      </div>
    )
  }

  if (role === 'none') {
    return (
      <Card>
        <CardHeader><CardTitle>管理后台</CardTitle></CardHeader>
        <CardContent>
          <p className="text-destructive">当前钱包无管理权限（非合约 Owner 或 Resolver）。</p>
          <p className="mt-2 text-xs text-muted">角色判定仅供 UX 展示，真实权限由链上 onlyOwner / resolvers 控制。</p>
        </CardContent>
      </Card>
    )
  }

  if (role === 'unknown') {
    return (
      <div className="space-y-4">
        <Skeleton className="h-8 w-40" />
        <Skeleton className="h-40 w-full" />
        <Skeleton className="h-48 w-full" />
      </div>
    )
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-2">
        <h2 className="text-xl font-bold">管理后台</h2>
        <Badge variant={ROLE_VARIANT[role]}>{ROLE_LABEL[role]}</Badge>
      </div>
      <Card>
        <CardHeader><CardTitle>只读信息</CardTitle></CardHeader>
        <CardContent className="space-y-2 text-sm">
          <div><span className="text-muted">链：</span>{CHAIN_NAME} (ID {CHAIN_ID})</div>
          <Copyable text={PREDICTION_MARKET_ADDRESS} label="市场合约：" />
          {owner && <Copyable text={owner as string} label="合约 Owner：" />}
          <div><span className="text-muted">当前钱包：</span>{address}</div>
          <div>
            <span className="text-muted">连接链：</span>
            {onRightChain ? '一致' : <span className="text-destructive">不一致（请切换到 {CHAIN_NAME}）</span>}
          </div>
          <p className="pt-2 text-xs text-muted">
            角色判定仅供 UX，安全边界在链上合约。
            {role === 'owner' && ' 最佳实践：Owner 使用冷 key 保管，resolver 使用热 key 日常结算。'}
          </p>
        </CardContent>
      </Card>

      {role === 'owner' && (
        <Card>
          <CardHeader><CardTitle>Resolver 授权管理</CardTitle></CardHeader>
          <CardContent className="space-y-3">
            <p className="text-xs text-muted">合约无 enumerable 列表，只能按地址查询后授权/撤销。</p>
            <div className="flex flex-wrap items-center gap-2">
              <Input
                value={addrInput}
                onChange={(e) => setAddrInput(e.target.value)}
                placeholder="0x... 输入 operator 地址"
                className="max-w-sm font-mono text-xs"
              />
              {validAddr && (
                <Badge variant={targetIsResolver ? 'success' : 'secondary'}>
                  {targetIsResolver ? '已授权' : '未授权'}
                </Badge>
              )}
            </div>
            <div className="flex gap-2">
              <Button
                disabled={!validAddr || isSetResolverPending || !onRightChain}
                onClick={() => handleSetResolver(true)}
              >
                {isSetResolverPending ? <><Loader2 className="h-4 w-4 animate-spin" /> 确认中...</> : '授权为 Resolver'}
              </Button>
              <Button
                variant="outline"
                disabled={!validAddr || isSetResolverPending || !onRightChain}
                className="border-destructive/40 text-destructive hover:bg-destructive/10"
                onClick={() => handleSetResolver(false)}
              >
                {isSetResolverPending ? <><Loader2 className="h-4 w-4 animate-spin" /> 确认中...</> : '撤销授权'}
              </Button>
            </div>
            <div className="rounded-lg bg-amber-500/10 p-3 text-xs text-amber-700">
              撤销前注意：若该 key 已在链上结算错误结果，请先用备用 owner/resolver key 调 <code>disputeResolve</code> 纠正，
              再撤销 bad key；仅撤销无法回滚已上链结果。
            </div>
          </CardContent>
        </Card>
      )}
      {/* Task 5 注入：结算区（owner + operator） */}
    </div>
  )
}