import { useEffect, useMemo, useState, useRef } from 'react'
import { useReadContracts } from 'wagmi'
import { useMarketCount } from '../hooks/useMarket'
import { PREDICTION_MARKET_ADDRESS, predictionMarketABI } from '../contracts/abi'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { CATEGORIES, CATEGORY_OTHER, classifyQuestion } from '../lib/categories'
import { SearchBar } from '../components/SearchBar'
import { useToast } from '../components/Toast'
import { filterAndSort, type FilterState, type MarketData } from '../lib/filters'
import { Skeleton } from '@/components/ui/skeleton'
import type { MarketTuple } from '../hooks/useMarket'

interface Props {
  onSelect: (id: number) => void
}

const PAGE_SIZE = 12

const CATEGORY_LABELS: Record<string, string> = Object.fromEntries(
  [...CATEGORIES.map((c) => [c.id, c.label] as const), [CATEGORY_OTHER, '其他']]
)

const DEFAULT_FILTERS: FilterState = { search: '', sort: 'newest', status: 'all', category: 'all' }

function useMarketsMulticall(total: number) {
  const ids = useMemo(() => Array.from({ length: total }, (_, i) => i + 1), [total])
  const contracts = useMemo(
    () =>
      ids.map((id) => ({
        address: PREDICTION_MARKET_ADDRESS as `0x${string}`,
        abi: predictionMarketABI,
        functionName: 'markets' as const,
        args: [BigInt(id)] as const,
      })),
    [ids]
  )
  const { data, isLoading } = useReadContracts({ contracts, query: { enabled: total > 0 } })
  const markets = useMemo(() => {
    if (!data) return [] as MarketData[]
    return data
      .map((r, i) => (r.status === 'success' && r.result ? { id: ids[i], data: r.result as unknown as MarketTuple } : null))
      .filter((x): x is { id: number; data: MarketTuple } => x !== null)
      .map(({ id, data: m }) => ({
        id,
        question: m[0],
        outcomeYes: Number(m[1]) / 1e18,
        outcomeNo: Number(m[2]) / 1e18,
        deadline: Number(m[3]),
        status: m[4] as number,
        result: m[5] as boolean,
      }))
  }, [data, ids])
  return { markets, isLoading }
}

function MarketCard({ market, onSelect }: { market: MarketData; onSelect: (id: number) => void }) {
  const { id, question, outcomeYes, outcomeNo, deadline, status, result } = market
  const { toast } = useToast()
  const categoryId = classifyQuestion(question)
  const statusLabel = (() => {
    if (status === 1) return '已结算'
    if (status === 2) return '已取消'
    if (status === 0 && deadline * 1000 < Date.now()) return '待结算'
    return '进行中'
  })()
  const totalPool = outcomeYes + outcomeNo
  const yesPct = totalPool > 0 ? (outcomeYes / totalPool) * 100 : 50
  const isResolved = status === 1
  const isPendingResolve = status === 0 && deadline * 1000 < Date.now()

  return (
    <Card className={`transition-all hover:-translate-y-0.5 hover:shadow-md ${isResolved ? 'opacity-70' : ''}`}>
      <CardHeader>
        <div className="flex items-start justify-between gap-2">
          <CardTitle className="min-w-0 flex-1 text-base">{question}</CardTitle>
          <Badge className="shrink-0" variant={isResolved ? 'success' : isPendingResolve ? 'secondary' : status === 2 ? 'secondary' : 'default'}>
            {statusLabel}
          </Badge>
        </div>
      </CardHeader>
      <CardContent className="space-y-3">
        <div className="flex items-end justify-between">
          <div className="flex items-baseline gap-2">
            <span className="text-3xl font-bold text-yes">{yesPct.toFixed(0)}%</span>
            <span className="text-xs text-muted">YES 概率</span>
          </div>
          <span className="text-xs text-muted">截止 {new Date(deadline * 1000).toLocaleDateString()}</span>
        </div>
        <div className="flex h-2 overflow-hidden rounded-full bg-muted/15">
          <div className="bg-yes" style={{ width: `${yesPct}%` }} />
          <div className="bg-no" style={{ width: `${100 - yesPct}%` }} />
        </div>
        <div className="flex items-center justify-between text-xs">
          <button
            onClick={() => { navigator.clipboard.writeText(String(id)).then(() => toast(`市场 #${id} 已复制`, 'info')).catch(() => toast('复制失败', 'error')) }}
            className="flex items-center gap-1 rounded bg-muted/10 px-1.5 py-0.5 font-mono text-muted transition-colors hover:bg-muted/20"
            title="点击复制市场 ID"
          >
            #{id}
            <svg className="h-3 w-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
          </button>
          <span className="font-medium">{totalPool.toFixed(2)} CORN</span>
        </div>
        <div className="flex justify-between text-xs">
          <span className="text-yes font-medium">YES {outcomeYes.toFixed(2)} CORN</span>
          <span className="text-no font-medium">NO {outcomeNo.toFixed(2)} CORN</span>
        </div>
        {isResolved && <p className="text-xs text-muted">结果：{result ? 'YES 胜' : 'NO 胜'}</p>}
        <div className="flex items-center gap-2">
          <Badge variant="secondary" className="text-xs">{CATEGORY_LABELS[categoryId] ?? '其他'}</Badge>
          <Button className="ml-auto shrink-0" variant="outline" onClick={() => onSelect(id)}>查看详情</Button>
        </div>
      </CardContent>
    </Card>
  )
}

function TrendingMarket({ markets, onSelect }: { markets: MarketData[]; onSelect: (id: number) => void }) {
  const sorted = useMemo(
    () =>
      markets
        .filter((m) => m.status === 0 && m.outcomeYes + m.outcomeNo > 0)
        .sort((a, b) => b.outcomeYes + b.outcomeNo - (a.outcomeYes + a.outcomeNo))
        .slice(0, 5),
    [markets]
  )

  if (sorted.length === 0) return null

  return (
    <section>
      <h2 className="mb-3 text-lg font-bold">热门市场</h2>
      <div className="flex gap-4 overflow-x-auto pb-2 snap-x">
        {sorted.map((m) => {
          const totalPool = m.outcomeYes + m.outcomeNo
          const yesPct = totalPool > 0 ? (m.outcomeYes / totalPool) * 100 : 50
          return (
            <button
              key={m.id}
              data-testid="trending-card"
              onClick={() => onSelect(m.id)}
              className="group min-w-[280px] snap-start rounded-xl border border-border bg-card p-4 text-left shadow-sm transition-all hover:-translate-y-0.5 hover:shadow-md"
            >
              <div className="mb-2 flex items-center justify-between">
                <Badge variant="secondary" className="text-xs">{CATEGORY_LABELS[classifyQuestion(m.question)] ?? '其他'}</Badge>
                <span className="text-xs text-muted">{new Date(m.deadline * 1000).toLocaleDateString()}</span>
              </div>
              <p className="mb-3 line-clamp-2 text-sm font-medium">{m.question}</p>
              <div className="flex items-baseline gap-1">
                <span className="text-4xl font-extrabold text-yes">{yesPct.toFixed(0)}%</span>
                <span className="text-xs text-muted">YES</span>
              </div>
              <div className="mt-2 text-xs text-muted">资金池 {totalPool.toFixed(2)} CORN</div>
            </button>
          )
        })}
      </div>
    </section>
  )
}

export function MarketList({ onSelect }: Props) {
  const [filters, setFilters] = useState<FilterState>(DEFAULT_FILTERS)
  const [visibleCount, setVisibleCount] = useState(PAGE_SIZE)
  const sentinelRef = useRef<HTMLDivElement>(null)
  const { data: count, isLoading, isError, error } = useMarketCount()

  const total = Number(count ?? 0)
  const { markets: allMarkets, isLoading: marketsLoading } = useMarketsMulticall(total)

  const filtered = useMemo(() => filterAndSort(allMarkets, filters), [allMarkets, filters])
  const visible = useMemo(() => filtered.slice(0, visibleCount), [filtered, visibleCount])

  useEffect(() => {
    setVisibleCount(PAGE_SIZE)
  }, [filters])

  useEffect(() => {
    if (!sentinelRef.current || visibleCount >= filtered.length) return
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting) setVisibleCount((c) => c + PAGE_SIZE)
      },
      { rootMargin: '200px' }
    )
    observer.observe(sentinelRef.current)
    return () => observer.disconnect()
  }, [visibleCount, filtered.length])

  if (isLoading) return (
    <div className="space-y-4">
      <div className="flex items-center gap-2 text-sm text-muted">
        <div className="h-4 w-4 animate-spin rounded-full border-2 border-primary border-t-transparent" />
        <span>正在连接 RPC 节点...</span>
      </div>
      <Skeleton className="h-48 w-full" />
      <Skeleton className="h-10 w-full" />
      <div className="flex gap-2">
        <Skeleton className="h-8 w-16" /><Skeleton className="h-8 w-16" /><Skeleton className="h-8 w-16" />
      </div>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {[1,2,3,4,5,6].map(i => <Skeleton key={i} className="h-40 w-full" />)}
      </div>
    </div>
  )
  if (isError) return <p className="text-no">市场数量读取失败：{String(error?.shortMessage || error?.message || error)}</p>
  if (total === 0) return <p className="text-muted">暂无市场。</p>

  return (
    <div className="space-y-4">
      <TrendingMarket markets={allMarkets} onSelect={onSelect} />

      <SearchBar
        filters={filters}
        onChange={setFilters}
        totalCount={allMarkets.length}
        filteredCount={filtered.length}
      />

      <h2 className="text-xl font-bold">市场（{filtered.length}）</h2>

      <div className="flex flex-wrap gap-2">
        <Button
          key="all"
          variant={filters.category === 'all' ? 'default' : 'outline'}
          size="sm"
          onClick={() => setFilters((f) => ({ ...f, category: 'all' }))}
        >
          全部
        </Button>
        {CATEGORIES.map((cat) => (
          <Button
            key={cat.id}
            variant={filters.category === cat.id ? 'default' : 'outline'}
            size="sm"
            className="min-w-0"
            onClick={() => setFilters((f) => ({ ...f, category: cat.id }))}
          >
            {cat.label}
          </Button>
        ))}
      </div>

      {marketsLoading && allMarkets.length === 0 && (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {[1,2,3,4,5,6].map(i => <Skeleton key={i} className="h-40 w-full" />)}
        </div>
      )}

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {visible.map((m) => (
          <MarketCard key={m.id} market={m} onSelect={onSelect} />
        ))}
      </div>

      {allMarkets.length > 0 && filtered.length === 0 && (
        <p className="text-muted">没有匹配的市场。</p>
      )}

      {visibleCount < filtered.length && <div ref={sentinelRef} className="h-4" />}
    </div>
  )
}
