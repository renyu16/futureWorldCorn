import { useEffect, useRef, useState, useCallback } from 'react'
import { usePublicClient } from 'wagmi'
import { PREDICTION_MARKET_ADDRESS, predictionMarketABI } from '@/contracts/abi'
import { getLogsChunked } from '@/lib/getLogsChunked'
import { createChart, type IChartApi, type ISeriesApi, ColorType, LineSeries } from 'lightweight-charts'

interface PricePoint {
  time: number
  yesPrice: number
  noPrice: number
}

export function usePriceHistory(marketId: number) {
  const publicClient = usePublicClient()
  const [data, setData] = useState<PricePoint[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const loadedMarketRef = useRef<number | null>(null)

  useEffect(() => {
    if (!publicClient) return
    if (loadedMarketRef.current === marketId) return
    loadedMarketRef.current = marketId
    setIsLoading(true)

    const address = PREDICTION_MARKET_ADDRESS as `0x${string}`
    getLogsChunked(publicClient, {
      address,
      event: {
        type: 'event',
        name: 'BetPlaced',
        inputs: [
          { type: 'uint256', name: 'id', indexed: true },
          { type: 'address', name: 'user', indexed: true },
          { type: 'uint8', name: 'outcome' },
          { type: 'uint256', name: 'amount' },
        ],
      },
      args: { id: BigInt(marketId) },
    }).then(async (logs) => {
      if (logs.length === 0) {
        setData([])
        setIsLoading(false)
        return
      }

      const marketData = await publicClient.readContract({
        address: PREDICTION_MARKET_ADDRESS as `0x${string}`,
        abi: predictionMarketABI,
        functionName: 'markets',
        args: [BigInt(marketId)],
      })
      const [, currentYes, currentNo] = marketData as [string, bigint, bigint, number, number, boolean, number]
      const totalEventYes = logs.reduce((sum, l) => sum + ((l.args as any).outcome === 0 ? Number((l.args as any).amount) : 0), 0)
      const totalEventNo = logs.reduce((sum, l) => sum + ((l.args as any).outcome === 1 ? Number((l.args as any).amount) : 0), 0)
      let cumYes = Number(currentYes) - totalEventYes
      let cumNo = Number(currentNo) - totalEventNo

      const blocks = await Promise.all(logs.map(l => publicClient.getBlock({ blockNumber: l.blockNumber })))
      const points: PricePoint[] = logs.map((log, i) => {
        const time = Number(blocks[i].timestamp)
        const amount = Number((log.args as any).amount)
        if ((log.args as any).outcome === 0) cumYes += amount
        else cumNo += amount
        const total = cumYes + cumNo
        const yesPrice = total > 0 ? cumYes / total : 0.5
        return { time, yesPrice, noPrice: 1 - yesPrice }
      })

      setData(points)
      setIsLoading(false)
    }).catch(() => {
      setIsLoading(false)
    })
  }, [publicClient?.uid, marketId])

  return { data, isLoading }
}

interface PriceChartProps {
  data: PricePoint[]
}

export function PriceChart({ data }: PriceChartProps) {
  const containerRef = useRef<HTMLDivElement>(null)
  const chartRef = useRef<IChartApi | null>(null)
  const yesSeriesRef = useRef<ISeriesApi<'Line'> | null>(null)
  const noSeriesRef = useRef<ISeriesApi<'Line'> | null>(null)

  const initChart = useCallback(() => {
    if (!containerRef.current) return
    if (chartRef.current) return

    const chart = createChart(containerRef.current, {
      layout: {
        background: { type: ColorType.Solid, color: 'transparent' },
        textColor: '#737373',
      },
      grid: {
        vertLines: { color: '#e5e5e5' },
        horzLines: { color: '#e5e5e5' },
      },
      width: containerRef.current.clientWidth,
      height: 200,
      timeScale: {
        timeVisible: true,
        secondsVisible: false,
      },
      rightPriceScale: {
        scaleMargins: { top: 0.1, bottom: 0.1 },
      },
    })

    const yesSeries = chart.addSeries(LineSeries, {
      color: '#16a34a',
      lineWidth: 2,
      priceFormat: { type: 'percent' },
    })

    const noSeries = chart.addSeries(LineSeries, {
      color: '#dc2626',
      lineWidth: 2,
      priceFormat: { type: 'percent' },
    })

    chartRef.current = chart
    yesSeriesRef.current = yesSeries
    noSeriesRef.current = noSeries

    const handleResize = () => {
      if (containerRef.current && chartRef.current) {
        chartRef.current.applyOptions({ width: containerRef.current.clientWidth })
      }
    }
    window.addEventListener('resize', handleResize)
    return () => window.removeEventListener('resize', handleResize)
  }, [])

  useEffect(() => {
    const cleanup = initChart()
    return () => {
      cleanup?.()
      if (chartRef.current) {
        chartRef.current.remove()
        chartRef.current = null
      }
    }
  }, [initChart])

  useEffect(() => {
    if (!yesSeriesRef.current || !noSeriesRef.current || data.length === 0) return

    const yesData = data.map(d => ({ time: d.time as any, value: d.yesPrice * 100 }))
    const noData = data.map(d => ({ time: d.time as any, value: d.noPrice * 100 }))

    yesSeriesRef.current.setData(yesData)
    noSeriesRef.current.setData(noData)

    if (chartRef.current) {
      chartRef.current.timeScale().fitContent()
    }
  }, [data])

  if (data.length === 0) {
    return (
      <div className="flex items-center justify-center h-[200px] rounded-lg border border-border bg-muted/5 text-sm text-muted">
        暂无价格数据
      </div>
    )
  }

  return (
    <div className="relative rounded-lg border border-border bg-card p-2">
      <div ref={containerRef} className="w-full" />
      <div className="absolute top-4 left-4 flex gap-3 text-xs">
        <span className="flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-yes" />是 (Yes)</span>
        <span className="flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-no" />否 (No)</span>
      </div>
    </div>
  )
}
