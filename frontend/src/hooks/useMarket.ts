import { useReadContract, useWriteContract } from 'wagmi'
import { PREDICTION_MARKET_ADDRESS, predictionMarketABI } from '../contracts/abi'

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
