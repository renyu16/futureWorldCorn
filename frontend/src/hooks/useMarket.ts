import { useReadContract, useWriteContract } from 'wagmi'
import { PREDICTION_MARKET_ADDRESS, predictionMarketABI } from '../contracts/abi'

export type MarketTuple = readonly [
  question: string,
  outcomeYes: bigint,
  outcomeNo: bigint,
  deadline: bigint,
  status: number,
  result: boolean,
  feeBps: number,
]

export function useMarketCount() {
  return useReadContract({
    address: PREDICTION_MARKET_ADDRESS,
    abi: predictionMarketABI,
    functionName: 'marketCount',
  })
}

export function useMarket(id: number) {
  return useReadContract({
    address: PREDICTION_MARKET_ADDRESS,
    abi: predictionMarketABI,
    functionName: 'markets',
    args: [BigInt(id)],
  })
}

export function useMarketTuple(id: number) {
  const { data, ...rest } = useMarket(id)
  return { ...rest, data: data as MarketTuple | undefined }
}

export function useWriteBet() {
  return useWriteContract()
}

export function useWriteCreateMarket() {
  return useWriteContract()
}

export function useWriteClaimReward() {
  return useWriteContract()
}

export function useWriteResolveMarket() {
  return useWriteContract()
}
