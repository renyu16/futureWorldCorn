import { useReadContract, useWriteContract } from 'wagmi'
import { CORN_TOKEN_ADDRESS, cornTokenABI } from '../contracts/abi'

export function useTokenBalance(address: `0x${string}` | undefined) {
  return useReadContract({
    address: CORN_TOKEN_ADDRESS,
    abi: cornTokenABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  })
}

export function useTokenAllowance(owner: `0x${string}` | undefined, spender: `0x${string}` | undefined) {
  return useReadContract({
    address: CORN_TOKEN_ADDRESS,
    abi: cornTokenABI,
    functionName: 'allowance',
    args: owner && spender ? [owner, spender] : undefined,
  })
}

export function useWriteApprove() {
  return useWriteContract()
}
