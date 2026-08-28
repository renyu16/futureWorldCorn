import { useEffect, useRef, useState } from 'react'
import { usePublicClient } from 'wagmi'
import { PREDICTION_MARKET_ADDRESS } from '@/contracts/abi'
import { getLogsChunked } from '@/lib/getLogsChunked'
import { CheckCircle, Clock, AlertTriangle, Gavel, Circle } from 'lucide-react'

interface TimelineEvent {
  type: 'created' | 'deadline' | 'resolved' | 'disputed'
  label: string
  detail?: string
  time?: number
}

interface MarketTimelineProps {
  marketId: number
  status: number
  result: boolean
  deadline: number
}

export function MarketTimeline({ marketId, status, result, deadline }: MarketTimelineProps) {
  const publicClient = usePublicClient()
  const [events, setEvents] = useState<TimelineEvent[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const loadedMarketRef = useRef<number | null>(null)

  useEffect(() => {
    if (!publicClient) return
    if (loadedMarketRef.current === marketId) return
    loadedMarketRef.current = marketId

    const fetchEvents = async () => {
      const timeline: TimelineEvent[] = []

      // 1. Market creation
      try {
        const createdLogs = await getLogsChunked(publicClient, {
          address: PREDICTION_MARKET_ADDRESS as `0x${string}`,
          event: {
            type: 'event',
            name: 'MarketCreated',
            inputs: [
              { type: 'uint256', name: 'id', indexed: true },
              { type: 'string', name: 'question' },
              { type: 'uint40', name: 'deadline' },
            ],
          },
          args: { id: BigInt(marketId) },
        })
        if (createdLogs.length > 0) {
          const block = await publicClient.getBlock({ blockNumber: createdLogs[0].blockNumber })
          timeline.push({
            type: 'created',
            label: '市场创建',
            time: Number(block.timestamp),
          })
        }
      } catch {}

      // 2. Deadline
      timeline.push({
        type: 'deadline',
        label: '截止下注',
        detail: status === 0 && Date.now() / 1000 > deadline ? '已过截止' : '等待中',
        time: deadline,
      })

      // 3. Resolution
      if (status === 1) {
        try {
          const resolvedLogs = await getLogsChunked(publicClient, {
            address: PREDICTION_MARKET_ADDRESS as `0x${string}`,
            event: {
              type: 'event',
              name: 'MarketResolved',
              inputs: [
                { type: 'uint256', name: 'id', indexed: true },
                { type: 'bool', name: 'result' },
              ],
            },
            args: { id: BigInt(marketId) },
          })
          if (resolvedLogs.length > 0) {
            const block = await publicClient.getBlock({ blockNumber: resolvedLogs[0].blockNumber })
            timeline.push({
              type: 'resolved',
              label: '市场结算',
              detail: result ? 'YES 胜出' : 'NO 胜出',
              time: Number(block.timestamp),
            })
          }
        } catch {}
      } else if (status === 2) {
        timeline.push({
          type: 'resolved',
          label: '市场取消',
          detail: '已取消',
        })
      }

      // 4. Disputes
      try {
        const disputeLogs = await getLogsChunked(publicClient, {
          address: PREDICTION_MARKET_ADDRESS as `0x${string}`,
          event: {
            type: 'event',
            name: 'MarketDisputed',
            inputs: [
              { type: 'uint256', name: 'id', indexed: true },
              { type: 'uint256', name: 'disputeId' },
            ],
          },
          args: { id: BigInt(marketId) },
        })
        for (const log of disputeLogs) {
          const block = await publicClient.getBlock({ blockNumber: log.blockNumber })
          timeline.push({
            type: 'disputed',
            label: '争议提交',
            detail: `争议 #${log.args.disputeId?.toString()}`,
            time: Number(block.timestamp),
          })
        }
      } catch {}

      timeline.sort((a, b) => (a.time ?? 0) - (b.time ?? 0))
      setEvents(timeline)
      setIsLoading(false)
    }

    fetchEvents().catch(() => setIsLoading(false))
  }, [publicClient?.uid, marketId, status, result, deadline])

  if (isLoading) {
    return <div className="text-sm text-muted py-4">加载时间线...</div>
  }

  if (events.length === 0) return null

  const ICONS = {
    created: Circle,
    deadline: Clock,
    resolved: result ? CheckCircle : Gavel,
    disputed: AlertTriangle,
  }

  const COLORS = {
    created: 'bg-blue-500',
    deadline: 'bg-yellow-500',
    resolved: 'bg-yes',
    disputed: 'bg-amber-500',
  }

  return (
    <div className="space-y-3">
      <h3 className="font-semibold text-sm">市场时间线</h3>
      <div className="relative ml-2">
        <div className="absolute left-2 top-2 bottom-2 w-px bg-border" />
        <div className="space-y-4">
          {events.map((event, i) => {
            const Icon = ICONS[event.type]
            return (
              <div key={i} className="relative flex gap-3">
                <div className={`relative z-10 flex h-5 w-5 items-center justify-center rounded-full ${COLORS[event.type]} shrink-0 mt-0.5`}>
                  <Icon className="h-3 w-3 text-white" />
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center justify-between gap-2">
                    <span className="font-medium text-sm">{event.label}</span>
                    {event.time && (
                      <span className="text-xs text-muted shrink-0">
                        {new Date(event.time * 1000).toLocaleString()}
                      </span>
                    )}
                  </div>
                  {event.detail && (
                    <p className="text-xs text-muted mt-0.5">{event.detail}</p>
                  )}
                </div>
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}
