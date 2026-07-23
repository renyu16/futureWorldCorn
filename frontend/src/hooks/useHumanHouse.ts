import { useReadContract, useWriteContract, usePublicClient } from 'wagmi'
import { HUMAN_HOUSE_ADDRESS, humanHouseABI } from '../contracts/abi'

// Read hooks
export function useDisputeDeposit() {
  return useReadContract({
    address: HUMAN_HOUSE_ADDRESS,
    abi: humanHouseABI,
    functionName: 'disputeDeposit',
  })
}

export function useVotingPeriod() {
  return useReadContract({
    address: HUMAN_HOUSE_ADDRESS,
    abi: humanHouseABI,
    functionName: 'votingPeriod',
  })
}

export function useDisputeCount() {
  return useReadContract({
    address: HUMAN_HOUSE_ADDRESS,
    abi: humanHouseABI,
    functionName: 'disputeCount',
  })
}

export function useDispute(disputeId: bigint | undefined) {
  return useReadContract({
    address: HUMAN_HOUSE_ADDRESS,
    abi: humanHouseABI,
    functionName: 'disputes',
    args: disputeId !== undefined ? [disputeId] : undefined,
  })
}

// Write hooks
export function useRaiseDispute() {
  return useWriteContract()
}

export function useVote() {
  return useWriteContract()
}

export function useExecuteDispute() {
  return useWriteContract()
}

// Event log fetcher
export async function fetchDisputeCreatedLogs(publicClient: any) {
  return publicClient.getLogs({
    address: HUMAN_HOUSE_ADDRESS,
    event: {
      type: 'event',
      name: 'DisputeCreated',
      inputs: [
        { type: 'uint256', name: 'disputeId', indexed: true },
        { type: 'uint256', name: 'marketId', indexed: true },
        { type: 'uint8', name: 'disputeType' },
        { type: 'string', name: 'reason' },
      ],
    },
    fromBlock: 0n,
    toBlock: 'latest',
  })
}
