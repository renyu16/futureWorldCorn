import { useState } from 'react'
import { useAccount, useReadContract } from 'wagmi'
import { useMarketTuple, useWriteBet, useWriteClaimReward, useWriteResolveMarket } from '../hooks/useMarket'
import { useTokenBalance, useTokenAllowance, useWriteApprove } from '../hooks/useToken'
import { CORN_TOKEN_ADDRESS, cornTokenABI, PREDICTION_MARKET_ADDRESS, predictionMarketABI } from '../contracts/abi'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Badge } from '@/components/ui/badge'
import { ArrowLeft } from 'lucide-react'

interface Props {
  marketId: number
}

export function MarketDetail({ marketId }: Props) {
  const { address } = useAccount()
  const { data: market, isLoading } = useMarketTuple(marketId)
  const { data: balance } = useTokenBalance(address)
  const { data: allowance } = useTokenAllowance(address, PREDICTION_MARKET_ADDRESS)
  const { data: owner } = useReadContract({
    address: PREDICTION_MARKET_ADDRESS,
    abi: predictionMarketABI,
    functionName: 'owner',
  })
  const { writeContract: approve } = useWriteApprove()
  const { writeContract: bet } = useWriteBet()
  const { writeContract: claim } = useWriteClaimReward()
  const { writeContract: resolve } = useWriteResolveMarket()

  const [betAmount, setBetAmount] = useState('')
  const [selectedOutcome, setSelectedOutcome] = useState<number>(0)

  if (isLoading) return <p className="text-muted">Loading market...</p>
  if (!market) return <p className="text-muted">Market not found</p>

  const [question, outcomeYes, outcomeNo, deadline, status, result] = market
  const statusLabel = ['Open', 'Resolved', 'Cancelled'][status as number] ?? 'Unknown'
  const yesPool = Number(outcomeYes) / 1e18
  const noPool = Number(outcomeNo) / 1e18
  const userBalance = balance ? Number(balance) / 1e18 : 0
  const userAllowance = allowance ? Number(allowance) / 1e18 : 0
  const isOpen = status === 0
  const isResolved = status === 1
  const amountParsed = BigInt(Math.floor(parseFloat(betAmount || '0') * 1e18))
  const isOwner = address && owner ? address.toLowerCase() === (owner as string).toLowerCase() : false
  const deadlinePassed = Number(deadline) * 1000 < Date.now()

  const handleBet = async () => {
    if (!address || amountParsed <= 0n) return
    if (userAllowance < parseFloat(betAmount || '0')) {
      approve({
        address: CORN_TOKEN_ADDRESS, abi: cornTokenABI, functionName: 'approve',
        args: [PREDICTION_MARKET_ADDRESS, amountParsed],
      })
    } else {
      bet({
        address: PREDICTION_MARKET_ADDRESS, abi: predictionMarketABI, functionName: 'bet',
        args: [BigInt(marketId), selectedOutcome, amountParsed],
      })
    }
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
      <Button variant="ghost" size="sm" onClick={() => window.history.back()} className="text-muted">
        <ArrowLeft className="mr-2 h-4 w-4" /> Back
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
            <div><span className="text-muted">Deadline:</span><br />{new Date(Number(deadline) * 1000).toLocaleString()}</div>
            <div><span className="text-muted">Result:</span><br />{isResolved ? (result ? 'YES Won' : 'NO Won') : '-'}</div>
            <div><span className="text-yes font-medium">YES Pool:</span><br />{yesPool.toFixed(4)} CORN</div>
            <div><span className="text-no font-medium">NO Pool:</span><br />{noPool.toFixed(4)} CORN</div>
          </div>
          <div className="rounded-lg bg-muted/10 p-3 text-sm">
            <span className="text-muted">Your Balance:</span> <span className="font-medium">{userBalance.toFixed(4)} CORN</span>
          </div>

          {isOpen && address && (
            <div className="space-y-3 border-t border-border pt-4">
              <h3 className="font-semibold">Place Bet</h3>
              <div className="space-y-2">
                <Label>Outcome</Label>
                <Select value={String(selectedOutcome)} onValueChange={(v) => setSelectedOutcome(Number(v))}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="0">YES</SelectItem>
                    <SelectItem value="1">NO</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label>Amount (CORN)</Label>
                <Input type="number" placeholder="0.00" min="0" step="0.01" value={betAmount} onChange={(e) => setBetAmount(e.target.value)} />
              </div>
              <Button className="w-full" disabled={!betAmount || parseFloat(betAmount) <= 0} onClick={handleBet}>
                {userAllowance < parseFloat(betAmount || '0') ? 'Approve' : 'Bet'}
              </Button>
            </div>
          )}

          {isResolved && address && (
            <div className="border-t border-border pt-4">
              <Button className="w-full" onClick={handleClaim}>Claim Reward</Button>
            </div>
          )}

          {isOpen && isOwner && deadlinePassed && (
            <div className="space-y-3 border-t border-border pt-4">
              <h3 className="font-semibold">Resolve Market</h3>
              <p className="text-sm text-muted">Deadline has passed. Choose the winning outcome.</p>
              <div className="flex gap-2">
                <Button className="flex-1" variant="outline" onClick={() => handleResolve(true)}>Resolve YES Wins</Button>
                <Button className="flex-1" variant="outline" onClick={() => handleResolve(false)}>Resolve NO Wins</Button>
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
