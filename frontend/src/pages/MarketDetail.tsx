import { useState } from 'react'
import { useAccount, useReadContract } from 'wagmi'
import { useMarket, useWriteBet, useWriteClaimReward, useWriteResolveMarket } from '../hooks/useMarket'
import { useTokenBalance, useTokenAllowance, useWriteApprove } from '../hooks/useToken'
import { CORN_TOKEN_ADDRESS, PREDICTION_MARKET_ADDRESS, predictionMarketABI } from '../contracts/abi'

interface Props {
  marketId: number
}

export function MarketDetail({ marketId }: Props) {
  const { address } = useAccount()
  const { data: market, isLoading } = useMarket(marketId)
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

  if (isLoading) return <div>Loading market...</div>
  if (!market) return <div>Market not found</div>

  const [question, outcomeYes, outcomeNo, deadline, status, result] = market
  const statusLabel = ['Open', 'Resolved', 'Cancelled'][status as number] ?? 'Unknown'
  const yesPool = Number(outcomeYes) / 1e18
  const noPool = Number(outcomeNo) / 1e18
  const userBalance = balance ? Number(balance) / 1e18 : 0
  const userAllowance = allowance ? Number(allowance) / 1e18 : 0
  const isOpen = status === 0
  const isResolved = status === 1
  const amountParsed = BigInt(Math.floor(parseFloat(betAmount || '0') * 1e18))

  // owner + deadline checks for resolve UI
  const isOwner = address && owner ? address.toLowerCase() === (owner as string).toLowerCase() : false
  const deadlinePassed = Number(deadline) * 1000 < Date.now()

  const handleBet = async () => {
    if (!address || amountParsed <= 0n) return
    if (userAllowance < parseFloat(betAmount || '0')) {
      approve({
        address: CORN_TOKEN_ADDRESS,
        abi: [
          'function approve(address spender, uint256 amount) returns (bool)',
        ],
        functionName: 'approve',
        args: [PREDICTION_MARKET_ADDRESS, amountParsed],
      })
    } else {
      bet({
        address: PREDICTION_MARKET_ADDRESS,
        abi: predictionMarketABI,
        functionName: 'bet',
        args: [BigInt(marketId), selectedOutcome, amountParsed],
      })
    }
  }

  const handleClaim = async () => {
    claim({
      address: PREDICTION_MARKET_ADDRESS,
      abi: predictionMarketABI,
      functionName: 'claimReward',
      args: [BigInt(marketId)],
    })
  }

  const handleResolve = async (win: boolean) => {
    resolve({
      address: PREDICTION_MARKET_ADDRESS,
      abi: predictionMarketABI,
      functionName: 'resolveMarket',
      args: [BigInt(marketId), win],
    })
  }

  return (
    <div>
      <h2>{question}</h2>
      <p>Deadline: {new Date(Number(deadline) * 1000).toLocaleString()}</p>
      <p>Status: {statusLabel}{isResolved && ` - ${result ? 'YES Won' : 'NO Won'}`}</p>
      <p>YES Pool: {yesPool.toFixed(4)} CORN | NO Pool: {noPool.toFixed(4)} CORN</p>
      <p>Your Balance: {userBalance.toFixed(4)} CORN</p>

      {isOpen && address && (
        <div style={{ marginTop: 16 }}>
          <h3>Place Bet</h3>
          <label>
            Outcome:
            <select value={selectedOutcome} onChange={(e) => setSelectedOutcome(Number(e.target.value))}>
              <option value={0}>YES</option>
              <option value={1}>NO</option>
            </select>
          </label>
          <br />
          <input
            type="number"
            placeholder="Amount in CORN"
            value={betAmount}
            onChange={(e) => setBetAmount(e.target.value)}
            min="0"
            step="0.01"
          />
          <br />
          <button onClick={handleBet} disabled={!betAmount || parseFloat(betAmount) <= 0}>
            {userAllowance < parseFloat(betAmount || '0') ? 'Approve' : 'Bet'}
          </button>
        </div>
      )}

      {isResolved && address && (
        <div style={{ marginTop: 16 }}>
          <button onClick={handleClaim}>Claim Reward</button>
        </div>
      )}

      {isOpen && isOwner && deadlinePassed && (
        <div style={{ marginTop: 16 }}>
          <h3>Resolve Market</h3>
          <p>Deadline has passed. Choose the winning outcome.</p>
          <button onClick={() => handleResolve(true)}>Resolve YES Wins</button>
          {' '}
          <button onClick={() => handleResolve(false)}>Resolve NO Wins</button>
        </div>
      )}
    </div>
  )
}
