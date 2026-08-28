import { useReadContract, useWriteContract } from 'wagmi'
import { HUMAN_HOUSE_ADDRESS, humanHouseABI } from '../contracts/abi'
import { getLogsChunked } from '../lib/getLogsChunked'

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

// Fetch all disputes via disputeCount + sequential reads (avoids 100+ getLogsChunked RPC calls)
export async function fetchAllDisputes(publicClient: any) {
  if (!HUMAN_HOUSE_ADDRESS.startsWith('0x') || HUMAN_HOUSE_ADDRESS.length < 42) return []
  const count = await publicClient.readContract({
    address: HUMAN_HOUSE_ADDRESS,
    abi: humanHouseABI,
    functionName: 'disputeCount',
  }) as bigint
  const results: Array<{ id: bigint; marketId: bigint; disputeType: number; reason: string }> = []
  for (let i = 1n; i <= count; i++) {
    const d = await publicClient.readContract({
      address: HUMAN_HOUSE_ADDRESS,
      abi: humanHouseABI,
      functionName: 'disputes',
      args: [i],
    }) as any[]
    results.push({
      id: i,
      marketId: d[0] as bigint,
      disputeType: Number(d[1]),
      reason: d[6] as string,
    })
  }
  return results.reverse()
}

export async function fetchVoteLogs(publicClient: any, disputeId?: bigint) {
  if (!HUMAN_HOUSE_ADDRESS.startsWith('0x') || HUMAN_HOUSE_ADDRESS.length < 42) return []
  const logs = await getLogsChunked(publicClient, {
    address: HUMAN_HOUSE_ADDRESS,
    event: {
      type: 'event',
      name: 'VoteCast',
      inputs: [
        { type: 'uint256', name: 'disputeId', indexed: true },
        { type: 'bool', name: 'support' },
      ],
    },
    args: disputeId !== undefined ? { disputeId } : undefined,
  })
  return Promise.all(logs.map(async (log: any) => {
    const block = await publicClient.getBlock({ blockNumber: log.blockNumber })
    return { ...log, timestamp: block.timestamp }
  }))
}

export async function fetchDisputeExecutedLogs(publicClient: any) {
  if (!HUMAN_HOUSE_ADDRESS.startsWith('0x') || HUMAN_HOUSE_ADDRESS.length < 42) return []
  const logs = await getLogsChunked(publicClient, {
    address: HUMAN_HOUSE_ADDRESS,
    event: {
      type: 'event',
      name: 'DisputeExecuted',
      inputs: [
        { type: 'uint256', name: 'disputeId', indexed: true },
        { type: 'uint8', name: 'outcome' },
        { type: 'uint256', name: 'votesFor' },
        { type: 'uint256', name: 'votesAgainst' },
      ],
    },
  })
  return Promise.all(logs.map(async (log: any) => {
    const block = await publicClient.getBlock({ blockNumber: log.blockNumber })
    return { ...log, timestamp: block.timestamp }
  }))
}
