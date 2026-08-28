import { useReadContracts } from 'wagmi'
import { useMarketCount, type MarketTuple } from './useMarket'
import { PREDICTION_MARKET_ADDRESS, predictionMarketABI } from '../contracts/abi'

export interface UserPosition {
  marketId: number
  question: string
  sharesYes: bigint
  sharesNo: bigint
  totalShares: bigint
  outcomeYes: bigint
  outcomeNo: bigint
  deadline: number
  status: number
  result: boolean
  feeBps: number
}

export function useUserPositions(userAddress: `0x${string}` | undefined) {
  const { data: count, isLoading: countLoading } = useMarketCount()
  const total = Number(count ?? 0)

  const marketAddr = PREDICTION_MARKET_ADDRESS as `0x${string}`
  const contracts = userAddress && total > 0
    ? Array.from({ length: total }, (_, i) => [
        {
          address: marketAddr,
          abi: predictionMarketABI,
          functionName: 'markets' as const,
          args: [BigInt(i + 1)],
        },
        {
          address: marketAddr,
          abi: predictionMarketABI,
          functionName: 'sharesYes' as const,
          args: [BigInt(i + 1), userAddress],
        },
        {
          address: marketAddr,
          abi: predictionMarketABI,
          functionName: 'sharesNo' as const,
          args: [BigInt(i + 1), userAddress],
        },
      ]).flat()
    : []

  const { data, isLoading, refetch } = useReadContracts({
    contracts,
  })

  const positions: UserPosition[] = []
  if (data && userAddress) {
    for (let i = 0; i < total; i++) {
      const baseIdx = i * 3
      const marketData = data[baseIdx]?.result as MarketTuple | undefined
      const sharesYes = data[baseIdx + 1]?.result as bigint | undefined
      const sharesNo = data[baseIdx + 2]?.result as bigint | undefined

      if (marketData && sharesYes !== undefined && sharesNo !== undefined) {
        const totalShares = sharesYes + sharesNo
        if (totalShares > 0n) {
          const [question, outcomeYes, outcomeNo, deadline, status, result, feeBps] = marketData
          positions.push({
            marketId: i + 1,
            question,
            sharesYes,
            sharesNo,
            totalShares,
            outcomeYes,
            outcomeNo,
            deadline: Number(deadline),
            status,
            result,
            feeBps,
          })
        }
      }
    }
  }

  return { positions, isLoading: countLoading || isLoading, refetch }
}
