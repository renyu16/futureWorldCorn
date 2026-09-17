import { useAccount, useChainId, useReadContract } from 'wagmi'
import { PREDICTION_MARKET_ADDRESS, predictionMarketABI } from '../contracts/abi'
import { CHAIN_ID, CHAIN_NAME, EXPLORER_URL } from '../config'
import { getAdminRole, isRightChain, type AdminRole } from '../lib/admin'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Skeleton } from '@/components/ui/skeleton'
import { WalletConnect } from '../components/WalletConnect'
import { useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { useWriteMarketResolve, useWriteSetResolver } from '../hooks/useMarket'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Loader2 } from 'lucide-react'
import { useToast } from '../components/Toast'
import { getMarketStatusLabel, isValidAddress } from '../lib/helpers'

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
  const { data: targetIsResolver, isFetching: isResolverFetching } = useReadContract({
    address: PREDICTION_MARKET_ADDRESS,
    abi: predictionMarketABI,
    functionName: 'resolvers',
    args: validAddr ? [addrInput.trim() as `0x${string}`] : undefined,
    query: { enabled: validAddr },
  })
  const { writeContract: resolve, isPending: isResolvePending } = useWriteMarketResolve()
  const [marketIdInput, setMarketIdInput] = useState('')
  const marketIdNum = Number(marketIdInput.trim())
  const marketIdValid = /^\d+$/.test(marketIdInput.trim()) && marketIdNum >= 0
  const [confirmState, setConfirmState] = useState<null | { marketId: number; win: boolean }>(null)
  const [succeed, setSucceed] = useState<{ marketId: number; txHash: string } | null>(null)
  const { data: mktData } = useReadContract({
    address: PREDICTION_MARKET_ADDRESS,
    abi: predictionMarketABI,
    functionName: 'markets',
    args: marketIdValid ? [BigInt(marketIdNum)] : undefined,
    query: { enabled: marketIdValid },
  })
  const mkt = mktData as readonly string[] | undefined
  const mktStatus = mkt ? Number(mkt[4]) : undefined
  const mktDeadline = mkt ? Number(mkt[3]) : undefined
  const mktDeadlinePassed = mktDeadline !== undefined && mktDeadline * 1000 < Date.now()
  const mktSettlable = mktStatus === 0 && mktDeadlinePassed
  const mktStatusLabel = mktStatus !== undefined && mktDeadline !== undefined
    ? getMarketStatusLabel(mktStatus, mktDeadline)
    : undefined

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

  const handleConfirm = (win: boolean) => {
    if (!marketIdValid || !mktSettlable || !onRightChain) return
    setConfirmState({ marketId: marketIdNum, win })
  }

  const handleExecute = async () => {
    if (!confirmState || !onRightChain) return
    const target = confirmState.marketId
    try {
      const hash = await new Promise<string>((res, rej) => {
        resolve(
          {
            address: PREDICTION_MARKET_ADDRESS,
            abi: predictionMarketABI,
            functionName: 'resolveMarket',
            args: [BigInt(target), confirmState.win],
          },
          {
            onSuccess: (h: `0x${string}`) => res(h),
            onError: (e: any) => rej(new Error(e.shortMessage ?? e.message)),
          }
        )
      })
      setSucceed({ marketId: target, txHash: hash })
      setConfirmState(null)
      queryClient.invalidateQueries({ queryKey: ['readContract'] })
      toast('结算交易已广播', 'info')
    } catch (e: any) {
      toast('交易失败: ' + (e.message || '未知错误'), 'error')
    }
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
                <Badge variant={isResolverFetching ? 'secondary' : targetIsResolver ? 'success' : 'secondary'}>
                  {isResolverFetching ? '查询中' : targetIsResolver ? '已授权' : '未授权'}
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
      <Card>
        <CardHeader><CardTitle>市场结算</CardTitle></CardHeader>
        <CardContent className="space-y-3">
          <p className="text-xs text-muted">输入 marketId，读取链上状态后选择获胜结果。交易前请逐项核对。结算实时链上校验：仅 Open 且已过 deadline 可结算。</p>
          <Input
            value={marketIdInput}
            onChange={(e) => { setMarketIdInput(e.target.value); setConfirmState(null); setSucceed(null) }}
            placeholder="输入 marketId，如 1"
            className="max-w-sm font-mono text-xs"
          />
          {marketIdValid && mkt && (
            <div className="space-y-1 rounded-lg bg-muted/10 p-3 text-xs">
              <div><span className="text-muted">市场：</span>{(mkt[0] as string) ?? ''}</div>
              <div>
                <span className="text-muted">状态：</span>
                {mktStatusLabel ?? '-'}
                <Badge className="ml-2" variant={mktSettlable ? 'success' : 'secondary'}>
                  {mktSettlable ? '可结算' : mktStatus === 1 ? '已结算' : mktStatus === 2 ? '已取消' : '未到截止时间'}
                </Badge>
              </div>
            </div>
          )}
          {marketIdValid && mkt && (
            <div className="flex gap-2">
              <Button className="flex-1" variant="outline" disabled={!mktSettlable || isResolvePending || !onRightChain} onClick={() => handleConfirm(true)}>
                结算 YES 胜
              </Button>
              <Button className="flex-1" variant="outline" disabled={!mktSettlable || isResolvePending || !onRightChain} onClick={() => handleConfirm(false)}>
                结算 NO 胜
              </Button>
            </div>
          )}
          {!onRightChain && address && (
            <p className="text-xs text-destructive">当前连接链 ({connectedChainId}) 与目标链 ({CHAIN_ID}) 不一致，操作已禁用。</p>
          )}

          {confirmState && (
            <div className="space-y-3 rounded-lg border border-amber-400/40 bg-amber-500/10 p-3 text-sm">
              <p className="font-semibold text-amber-700">最终确认 — 请逐项核对后提交钱包：</p>
              <ul className="list-disc pl-5 text-xs text-amber-800">
                <li>操作钱包：{address}</li>
                <li>目标链：{CHAIN_NAME}（{CHAIN_ID}）</li>
                <li>合约地址：{PREDICTION_MARKET_ADDRESS}</li>
                <li>操作：resolveMarket(marketId={confirmState.marketId}, result={confirmState.win ? 'TRUE(YES 胜)' : 'FALSE(NO 胜)'})</li>
                <li>链上状态：{mktStatusLabel}（应 Open 且已过 deadline）</li>
              </ul>
              <div className="ml-1 flex gap-2">
                <Button size="sm" disabled={isResolvePending} onClick={handleExecute}>
                  {isResolvePending ? <><Loader2 className="h-4 w-4 animate-spin" /> 确认中...</> : '确认并提交'}
                </Button>
                <Button size="sm" variant="ghost" onClick={() => setConfirmState(null)}>取消</Button>
              </div>
            </div>
          )}

          {succeed && (
            <div className="space-y-2 rounded-lg bg-muted/10 p-3 text-sm">
              <p className="text-green-600">结算交易已广播：{succeed.txHash}</p>
              <a href={`${EXPLORER_URL}/tx/${succeed.txHash}`} target="_blank" rel="noreferrer" className="inline-flex items-center gap-1 text-primary underline">
                在区块浏览器查看
              </a>
              <p className="text-xs text-amber-600">
                纠错提示：如结算结果有误，请用 owner 或备用 resolver key 调用 disputeResolve 纠正；若广播用的 key 已泄露，纠正后再 setResolver 撤销该 key。
              </p>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}