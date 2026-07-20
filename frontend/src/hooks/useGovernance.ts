import { useReadContract, useWriteContract } from 'wagmi'
import { TOKEN_HOUSE_ADDRESS, tokenHouseABI } from '../contracts/abi'

const STATE_NAMES: Record<number, string> = {
  0: 'Pending', 1: 'Active', 2: 'Canceled', 3: 'Defeated',
  4: 'Succeeded', 5: 'Queued', 6: 'Expired', 7: 'Executed',
}

export function useProposalState(proposalId: bigint | undefined) {
  const { data, ...rest } = useReadContract({
    address: TOKEN_HOUSE_ADDRESS,
    abi: tokenHouseABI,
    functionName: 'state',
    args: proposalId !== undefined ? [proposalId] : undefined,
  })
  return { data: data !== undefined ? STATE_NAMES[Number(data)] : undefined, raw: data, ...rest }
}

export function useProposalVotes(proposalId: bigint | undefined) {
  return useReadContract({
    address: TOKEN_HOUSE_ADDRESS,
    abi: tokenHouseABI,
    functionName: 'proposalVotes',
    args: proposalId !== undefined ? [proposalId] : undefined,
  })
}

export function useProposalProposer(proposalId: bigint | undefined) {
  return useReadContract({
    address: TOKEN_HOUSE_ADDRESS,
    abi: tokenHouseABI,
    functionName: 'proposalProposer',
    args: proposalId !== undefined ? [proposalId] : undefined,
  })
}

export function useProposalDeadline(proposalId: bigint | undefined) {
  return useReadContract({
    address: TOKEN_HOUSE_ADDRESS,
    abi: tokenHouseABI,
    functionName: 'proposalDeadline',
    args: proposalId !== undefined ? [proposalId] : undefined,
  })
}

export function useProposalSnapshot(proposalId: bigint | undefined) {
  return useReadContract({
    address: TOKEN_HOUSE_ADDRESS,
    abi: tokenHouseABI,
    functionName: 'proposalSnapshot',
    args: proposalId !== undefined ? [proposalId] : undefined,
  })
}

export function useCastVote() {
  return useWriteContract()
}
