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

  const depositAmt = parseEther(/^\d*\.?\d*$/.test(depositAmount) ? depositAmount : '0')
  const needsApprove = allowance !== undefined && depositAmt > 0n && depositAmt > (allowance as bigint)
  const refetchAll = () => { refetchCorn(); refetchGov(); refetchAllowance() }

  return (
    <div className="space-y-6">
      <h2 className="text-xl font-bold">Delegate</h2>
      {!address ? (
        <Card><CardContent className="p-6 text-muted">Connect your wallet to delegate.</CardContent></Card>
      ) : (
        <div className="space-y-6">
          <Card>
            <CardContent className="grid grid-cols-3 gap-4 p-6">
              <div><p className="text-xs text-muted">CORN Balance</p><p className="font-medium">{cornBalance ? formatEther(cornBalance as bigint) : '-'}</p></div>
              <div><p className="text-xs text-muted">govCORN Balance</p><p className="font-medium">{govCornBalance ? formatEther(govCornBalance as bigint) : '-'}</p></div>
              <div><p className="text-xs text-muted">Voting Power</p><p className="font-medium">{votes ? formatEther(votes as bigint) : '-'}</p></div>
            </CardContent>
          </Card>
          <Card>
            <CardHeader><CardTitle className="text-base">Deposit CORN → govCORN</CardTitle></CardHeader>
            <CardContent className="space-y-3">
              <div className="space-y-2">
                <Label>Amount</Label>
                <Input type="number" value={depositAmount} onChange={(e) => setDepositAmount(e.target.value)} placeholder="0.00" min="0" />
              </div>
              <div className="flex gap-2">
                <Button variant="outline" disabled={!needsApprove || depositAmt === 0n} onClick={() => writeContract({ address: CORN_TOKEN_ADDRESS, abi: cornTokenABI, functionName: 'approve', args: [GOV_CORN_TOKEN_ADDRESS, depositAmt] }, { onSuccess: () => refetchAllowance() })}>Approve</Button>
                <Button disabled={needsApprove || depositAmt === 0n} onClick={() => writeContract({ address: GOV_CORN_TOKEN_ADDRESS, abi: govCrownTokenABI, functionName: 'depositFor', args: [address, depositAmt] }, { onSuccess: () => refetchAll() })}>Deposit</Button>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardHeader><CardTitle className="text-base">Withdraw govCORN → CORN</CardTitle></CardHeader>
            <CardContent className="space-y-3">
              <div className="space-y-2">
                <Label>Amount</Label>
                <Input type="number" value={withdrawAmount} onChange={(e) => setWithdrawAmount(e.target.value)} placeholder="0.00" min="0" />
              </div>
              <Button disabled={/^\d*\.?\d*$/.test(withdrawAmount) && parseEther(withdrawAmount || '0') === 0n} onClick={() => writeContract({ address: GOV_CORN_TOKEN_ADDRESS, abi: govCrownTokenABI, functionName: 'withdrawTo', args: [address, parseEther(/^\d*\.?\d*$/.test(withdrawAmount) ? withdrawAmount : '0')] }, { onSuccess: () => refetchAll() })}>Withdraw</Button>
            </CardContent>
          </Card>
          <Card>
            <CardHeader><CardTitle className="text-base">Delegate Voting Power</CardTitle></CardHeader>
            <CardContent className="space-y-3">
              <div className="space-y-2">
                <Label>Delegatee Address</Label>
                <Input value={delegatee} onChange={(e) => setDelegatee(e.target.value)} placeholder="0x..." className="font-mono" />
              </div>
              <Button disabled={!delegatee} onClick={() => writeContract({ address: GOV_CORN_TOKEN_ADDRESS, abi: govCrownTokenABI, functionName: 'delegate', args: [delegatee as `0x${string}`] })}>Delegate</Button>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  )
}
