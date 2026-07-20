import { useState } from 'react'
import { useAccount } from 'wagmi'
import { useReadContract, useWriteContract } from 'wagmi'
import { parseEther, formatEther } from 'viem'
import {
  CORN_TOKEN_ADDRESS, cornTokenABI,
  GOV_CORN_TOKEN_ADDRESS, govCrownTokenABI,
} from '../contracts/abi'

export function Delegate() {
  const { address } = useAccount()
  const [depositAmount, setDepositAmount] = useState('')
  const [withdrawAmount, setWithdrawAmount] = useState('')
  const [delegatee, setDelegatee] = useState('')

  const { data: cornBalance, refetch: refetchCorn } = useReadContract({
    address: CORN_TOKEN_ADDRESS,
    abi: cornTokenABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  })
  const { data: govCornBalance, refetch: refetchGov } = useReadContract({
    address: GOV_CORN_TOKEN_ADDRESS,
    abi: govCrownTokenABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  })
  const { data: votes } = useReadContract({
    address: GOV_CORN_TOKEN_ADDRESS,
    abi: govCrownTokenABI,
    functionName: 'getVotes',
    args: address ? [address] : undefined,
  })
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: CORN_TOKEN_ADDRESS,
    abi: cornTokenABI,
    functionName: 'allowance',
    args: address ? [address, GOV_CORN_TOKEN_ADDRESS] : undefined,
  })

  const { writeContract } = useWriteContract()

  const depositAmt = parseEther(depositAmount || '0')
  const needsApprove = allowance !== undefined && depositAmt > 0n && depositAmt > (allowance as bigint)

  const refetchAll = () => { refetchCorn(); refetchGov(); refetchAllowance() }

  return (
    <div>
      <h2>Delegate</h2>
      {!address ? (
        <p>Connect your wallet to delegate.</p>
      ) : (
        <>
          <div style={{ border: '1px solid #ccc', padding: 12, borderRadius: 6, marginBottom: 16 }}>
            <p>CORN Balance: <strong>{cornBalance ? formatEther(cornBalance as bigint) : '—'}</strong></p>
            <p>govCORN Balance: <strong>{govCornBalance ? formatEther(govCornBalance as bigint) : '—'}</strong></p>
            <p>Voting Power: <strong>{votes ? formatEther(votes as bigint) : '—'}</strong></p>
          </div>

          <div style={{ border: '1px solid #ccc', padding: 12, borderRadius: 6, marginBottom: 16 }}>
            <h3>Deposit CORN → govCORN</h3>
            <input
              value={depositAmount} onChange={e => setDepositAmount(e.target.value)}
              placeholder="Amount" style={{ marginRight: 8 }}
            />
            <button
              disabled={!needsApprove || depositAmt === 0n}
              onClick={() => writeContract({
                address: CORN_TOKEN_ADDRESS, abi: cornTokenABI,
                functionName: 'approve',
                args: [GOV_CORN_TOKEN_ADDRESS, depositAmt],
              }, { onSuccess: () => refetchAllowance() })}
              style={{ marginRight: 8 }}
            >Approve</button>
            <button
              disabled={needsApprove || depositAmt === 0n}
              onClick={() => writeContract({
                address: GOV_CORN_TOKEN_ADDRESS, abi: govCrownTokenABI,
                functionName: 'depositFor',
                args: [address, depositAmt],
              }, { onSuccess: () => refetchAll() })}
            >Deposit</button>
          </div>

          <div style={{ border: '1px solid #ccc', padding: 12, borderRadius: 6, marginBottom: 16 }}>
            <h3>Withdraw govCORN → CORN</h3>
            <input
              value={withdrawAmount} onChange={e => setWithdrawAmount(e.target.value)}
              placeholder="Amount" style={{ marginRight: 8 }}
            />
            <button
              disabled={parseEther(withdrawAmount || '0') === 0n}
              onClick={() => writeContract({
                address: GOV_CORN_TOKEN_ADDRESS, abi: govCrownTokenABI,
                functionName: 'withdrawTo',
                args: [address, parseEther(withdrawAmount || '0')],
              }, { onSuccess: () => refetchAll() })}
            >Withdraw</button>
          </div>

          <div style={{ border: '1px solid #ccc', padding: 12, borderRadius: 6 }}>
            <h3>Delegate Voting Power</h3>
            <input
              value={delegatee} onChange={e => setDelegatee(e.target.value)}
              placeholder="0x..." style={{ marginRight: 8, width: 300 }}
            />
            <button
              disabled={!delegatee}
              onClick={() => writeContract({
                address: GOV_CORN_TOKEN_ADDRESS, abi: govCrownTokenABI,
                functionName: 'delegate',
                args: [delegatee as `0x${string}`],
              })}
            >Delegate</button>
          </div>
        </>
      )}
    </div>
  )
}
