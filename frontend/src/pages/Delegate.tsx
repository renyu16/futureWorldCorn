import { useState } from 'react'
import { useAccount, useReadContract, useWriteContract } from 'wagmi'
import { parseEther, formatEther } from 'viem'
import { CORN_TOKEN_ADDRESS, cornTokenABI, GOV_CORN_TOKEN_ADDRESS, govCrownTokenABI } from '../contracts/abi'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

export function Delegate() {
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
  const { writeContract } = useWriteContract()

  const isNumeric = (v: string) => v !== '' && /^\d*\.?\d*$/.test(v)
  const depositAmt = parseEther(isNumeric(depositAmount) ? depositAmount : '0')
  const withdrawAmt = parseEther(isNumeric(withdrawAmount) ? withdrawAmount : '0')
  const needsApprove = allowance !== undefined && depositAmt > 0n && depositAmt > (allowance as bigint)
  const refetchAll = () => { refetchCorn(); refetchGov(); refetchAllowance() }

  return (
    <div className="space-y-6">
      <h2 className="text-xl font-bold">委托</h2>
      {!address ? (
        <Card><CardContent className="p-6 text-muted">连接钱包以进行委托。</CardContent></Card>
      ) : (
        <div className="space-y-6">
          <Card>
            <CardContent className="grid grid-cols-3 gap-4 p-6">
              <div><p className="text-xs text-muted">CORN 余额</p><p className="font-medium">{cornBalance ? formatEther(cornBalance as bigint) : '-'}</p></div>
              <div><p className="text-xs text-muted">govCORN 余额</p><p className="font-medium">{govCornBalance ? formatEther(govCornBalance as bigint) : '-'}</p></div>
              <div><p className="text-xs text-muted">投票权</p><p className="font-medium">{votes ? formatEther(votes as bigint) : '-'}</p></div>
            </CardContent>
          </Card>
          <Card>
            <CardHeader><CardTitle className="text-base">Deposit CORN → govCORN</CardTitle></CardHeader>
            <CardContent className="space-y-3">
              <div className="space-y-2">
                <Label>数量</Label>
                <Input type="number" value={depositAmount} onChange={(e) => setDepositAmount(e.target.value)} placeholder="0.00" min="0" />
              </div>
              <div className="flex gap-2">
                <Button variant="outline" disabled={!needsApprove || depositAmt === 0n} onClick={() => writeContract({ address: CORN_TOKEN_ADDRESS, abi: cornTokenABI, functionName: 'approve', args: [GOV_CORN_TOKEN_ADDRESS, depositAmt] }, { onSuccess: () => refetchAllowance() })}>授权</Button>
                <Button disabled={needsApprove || depositAmt === 0n} onClick={() => writeContract({ address: GOV_CORN_TOKEN_ADDRESS, abi: govCrownTokenABI, functionName: 'depositFor', args: [address, depositAmt] }, { onSuccess: () => refetchAll() })}>存入</Button>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardHeader><CardTitle className="text-base">Withdraw govCORN → CORN</CardTitle></CardHeader>
            <CardContent className="space-y-3">
              <div className="space-y-2">
                <Label>数量</Label>
                <Input type="number" value={withdrawAmount} onChange={(e) => setWithdrawAmount(e.target.value)} placeholder="0.00" min="0" />
              </div>
              <Button disabled={withdrawAmt === 0n} onClick={() => writeContract({ address: GOV_CORN_TOKEN_ADDRESS, abi: govCrownTokenABI, functionName: 'withdrawTo', args: [address, withdrawAmt] }, { onSuccess: () => refetchAll() })}>提取</Button>
            </CardContent>
          </Card>
          <Card>
            <CardHeader><CardTitle className="text-base">委托投票权</CardTitle></CardHeader>
            <CardContent className="space-y-3">
              <div className="space-y-2">
                <Label>被委托人地址</Label>
                <Input value={delegatee} onChange={(e) => setDelegatee(e.target.value)} placeholder="0x..." className="font-mono" />
              </div>
              <Button disabled={!delegatee} onClick={() => writeContract({ address: GOV_CORN_TOKEN_ADDRESS, abi: govCrownTokenABI, functionName: 'delegate', args: [delegatee as `0x${string}`] })}>委托</Button>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  )
}
