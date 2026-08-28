import { useState } from 'react'
import { useAccount, useReadContract, useWriteContract } from 'wagmi'
import { parseEther, formatEther, isAddress } from 'viem'
import { CORN_TOKEN_ADDRESS, cornTokenABI, GOV_CORN_TOKEN_ADDRESS, govCrownTokenABI } from '../contracts/abi'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Loader2 } from 'lucide-react'
import { useToast } from '../components/Toast'
import { Skeleton } from '@/components/ui/skeleton'
import { isNumeric, needsApprove } from '../lib/helpers'

export function Delegate() {
  const { toast } = useToast()
  const { address } = useAccount()
  const [depositAmount, setDepositAmount] = useState('')
  const [withdrawAmount, setWithdrawAmount] = useState('')
  const [delegatee, setDelegatee] = useState('')

  const { data: cornBalance, refetch: refetchCorn } = useReadContract({
    address: CORN_TOKEN_ADDRESS, abi: cornTokenABI, functionName: 'balanceOf',
    args: address ? [address] : undefined,
  })
  const { data: govCornBalance, refetch: refetchGov } = useReadContract({
    address: GOV_CORN_TOKEN_ADDRESS, abi: govCrownTokenABI, functionName: 'balanceOf',
    args: address ? [address] : undefined,
  })
  const { data: votes } = useReadContract({
    address: GOV_CORN_TOKEN_ADDRESS, abi: govCrownTokenABI, functionName: 'getVotes',
    args: address ? [address] : undefined,
  })
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: CORN_TOKEN_ADDRESS, abi: cornTokenABI, functionName: 'allowance',
    args: address ? [address, GOV_CORN_TOKEN_ADDRESS] : undefined,
  })
  const { writeContract, isPending } = useWriteContract()

  const { data: myDelegate } = useReadContract({
    address: GOV_CORN_TOKEN_ADDRESS, abi: govCrownTokenABI, functionName: 'delegates',
    args: address ? [address] : undefined,
    query: { retry: 2 },
  })

  const isSelfDelegated = myDelegate && address && (myDelegate as string).toLowerCase() === address.toLowerCase()
  const delegateTarget = myDelegate as string | undefined
  const targetVotes = useReadContract({
    address: GOV_CORN_TOKEN_ADDRESS, abi: govCrownTokenABI, functionName: 'getVotes',
    args: delegateTarget && isAddress(delegateTarget) ? [delegateTarget as `0x${string}`] : undefined,
  })

  const isNumericValid = isNumeric(depositAmount)
  const depositAmt = parseEther(isNumericValid ? depositAmount : '0')
  const withdrawAmt = parseEther(isNumeric(withdrawAmount) ? withdrawAmount : '0')
  const needsApproval = needsApprove(depositAmt, allowance as bigint)
  const depositExceeds = cornBalance !== undefined && depositAmt > (cornBalance as bigint)
  const withdrawExceeds = govCornBalance !== undefined && withdrawAmt > (govCornBalance as bigint)
  const refetchAll = () => { refetchCorn(); refetchGov(); refetchAllowance() }

  return (
    <div className="space-y-6">
      <h2 className="text-xl font-bold">委托</h2>
      {!address ? (
        <Card><CardContent className="p-6 text-muted">连接钱包以进行委托。</CardContent></Card>
      ) : (
        <div className="space-y-6">
          <Card>
            <CardContent className="grid grid-cols-1 sm:grid-cols-3 gap-4 p-6">
              <div><p className="text-xs text-muted">CORN 余额</p><p className="font-medium">{cornBalance ? Number(formatEther(cornBalance as bigint)).toFixed(4) : '-'}</p></div>
              <div><p className="text-xs text-muted">govCORN 余额</p><p className="font-medium">{govCornBalance ? Number(formatEther(govCornBalance as bigint)).toFixed(4) : '-'}</p></div>
              <div><p className="text-xs text-muted">投票权</p><p className="font-medium">{votes ? Number(formatEther(votes as bigint)).toFixed(4) : '-'}</p></div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader><CardTitle className="text-base">当前委托</CardTitle></CardHeader>
            <CardContent>
              {delegateTarget && isAddress(delegateTarget) && delegateTarget !== '0x0000000000000000000000000000000000000000' ? (
                <div className="space-y-2">
                  <div className="flex items-center justify-between rounded bg-muted/10 px-3 py-3">
                    <div className="space-y-1">
                      <p className="text-xs text-muted">委托目标</p>
                      <p className="font-mono text-xs break-all">{delegateTarget}</p>
                    </div>
                    <div className="text-right shrink-0 ml-4">
                      <p className="text-xs text-muted">投票权</p>
                      <p className="font-medium">{targetVotes.data ? formatEther(targetVotes.data as bigint) : '-'}</p>
                    </div>
                  </div>
                  {isSelfDelegated && (
                    <p className="text-xs text-muted">当前为自我委托（默认状态），委托给他人后投票权将转移。</p>
                  )}
                </div>
              ) : (
                <>
                {myDelegate !== undefined
                  ? <p className="text-sm text-muted">未委托</p>
                  : <Skeleton className="h-4 w-24" />
                }
                </>
              )}
            </CardContent>
          </Card>

          <Card>
            <CardHeader><CardTitle className="text-base">Deposit CORN → govCORN</CardTitle></CardHeader>
            <CardContent className="space-y-3">
              <div className="space-y-2">
                <Label htmlFor="deposit-amount">数量</Label>
                <Input id="deposit-amount" type="number" value={depositAmount} onChange={(e) => setDepositAmount(e.target.value)} placeholder="0.00" min="0" />
              </div>
              <div className="flex gap-2">
                <Button variant="outline" className="min-w-0" disabled={!needsApproval || depositAmt === 0n || depositExceeds || isPending} onClick={() => { toast('交易已提交，请等待确认...', 'info'); writeContract({ address: CORN_TOKEN_ADDRESS, abi: cornTokenABI, functionName: 'approve', args: [GOV_CORN_TOKEN_ADDRESS, depositAmt] }, { onSuccess: () => { refetchAllowance(); toast('交易成功', 'success') }, onError: (e: any) => toast('交易失败: ' + (e.shortMessage ?? e.message), 'error') }) }}>
                  {isPending ? <><Loader2 className="h-4 w-4 animate-spin" /> 确认中...</> : '授权'}
                </Button>
                <Button className="min-w-0" disabled={needsApproval || depositAmt === 0n || depositExceeds || isPending} onClick={() => { toast('交易已提交，请等待确认...', 'info'); writeContract({ address: GOV_CORN_TOKEN_ADDRESS, abi: govCrownTokenABI, functionName: 'depositFor', args: [address, depositAmt] }, { onSuccess: () => { refetchAll(); toast('交易成功', 'success') }, onError: (e: any) => toast('交易失败: ' + (e.shortMessage ?? e.message), 'error') }) }}>
                  {isPending ? <><Loader2 className="h-4 w-4 animate-spin" /> 确认中...</> : '存入'}
                </Button>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardHeader><CardTitle className="text-base">Withdraw govCORN → CORN</CardTitle></CardHeader>
            <CardContent className="space-y-3">
              <div className="space-y-2">
                <Label htmlFor="withdraw-amount">数量</Label>
                <Input id="withdraw-amount" type="number" value={withdrawAmount} onChange={(e) => setWithdrawAmount(e.target.value)} placeholder="0.00" min="0" />
              </div>
              <Button disabled={withdrawAmt === 0n || withdrawExceeds || isPending} onClick={() => { toast('交易已提交，请等待确认...', 'info'); writeContract({ address: GOV_CORN_TOKEN_ADDRESS, abi: govCrownTokenABI, functionName: 'withdrawTo', args: [address, withdrawAmt] }, { onSuccess: () => { refetchAll(); toast('交易成功', 'success') }, onError: (e: any) => toast('交易失败: ' + (e.shortMessage ?? e.message), 'error') }) }}>
                {isPending ? <><Loader2 className="h-4 w-4 animate-spin" /> 确认中...</> : '提取'}
              </Button>
            </CardContent>
          </Card>
          <Card>
            <CardHeader><CardTitle className="text-base">委托投票权</CardTitle></CardHeader>
            <CardContent className="space-y-3">
              <div className="space-y-2">
                <Label htmlFor="delegatee-address">被委托人地址</Label>
                <Input id="delegatee-address" value={delegatee} onChange={(e) => setDelegatee(e.target.value)} placeholder="0x..." className="font-mono" />
              </div>
              <Button disabled={!delegatee || !isAddress(delegatee) || isPending} onClick={() => { toast('交易已提交，请等待确认...', 'info'); writeContract({ address: GOV_CORN_TOKEN_ADDRESS, abi: govCrownTokenABI, functionName: 'delegate', args: [delegatee as `0x${string}`] }, { onSuccess: () => { refetchAll(); toast('交易成功', 'success') }, onError: (e: any) => toast('交易失败: ' + (e.shortMessage ?? e.message), 'error') }) }}>
                {isPending ? <><Loader2 className="h-4 w-4 animate-spin" /> 确认中...</> : '委托'}
              </Button>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  )
}
