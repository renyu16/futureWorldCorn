import { useEffect, useMemo, useState } from 'react'
import { useMarketCount, useMarketTuple } from '../hooks/useMarket'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { CATEGORIES, CATEGORY_OTHER, classifyQuestion } from '../lib/categories'

interface Props {
  onSelect: (id: number) => void
}

const CATEGORY_LABELS: Record<string, string> = Object.fromEntries(
  [...CATEGORIES.map((c) => [c.id, c.label] as const), [CATEGORY_OTHER, '其他']]
)

interface MarketData {
  id: number
  question: string
  outcomeYes: bigint
  outcomeNo: bigint
  deadline: bigint
  status: number
  result: boolean
  categoryId: string
}

function MarketRow({
  id,
  category,
  onSelect,
  onStatus,
}: {
  id: number
  category: string
  onSelect: (id: number) => void
  onStatus: (id: number, loaded: boolean, visible: boolean) => void
}) {
  const { data: market, isLoading } = useMarketTuple(id)

  const question = market ? market[0] : ''
  const categoryId = classifyQuestion(question)
  const visible = category === 'all' || categoryId === category

  useEffect(() => {
    onStatus(id, !!market, visible)
  }, [id, visible, market, onStatus])

  if (isLoading || !market || !visible) return null

  const [q, outcomeYes, outcomeNo, deadline, status, result] = market
  return (
    <MarketCard
      market={{ id, question: q, outcomeYes, outcomeNo, deadline, status, result, categoryId }}
      onSelect={onSelect}
    />
  )
}

function MarketCard({ market, onSelect }: { market: MarketData; onSelect: (id: number) => void }) {
  const { question, outcomeYes, outcomeNo, deadline, status, result, categoryId } = market
  const statusLabel = ['进行中', '已结算', '已取消'][status] ?? '未知'
  const yesPool = Number(outcomeYes) / 1e18
  const noPool = Number(outcomeNo) / 1e18
  const totalPool = yesPool + noPool
  const yesPct = totalPool > 0 ? (yesPool / totalPool) * 100 : 50
  const isResolved = status === 1

  return (
    <Card className="transition-shadow hover:shadow-md">
      <CardHeader>
        <div className="flex items-start justify-between gap-2">
          <CardTitle className="text-base">{question}</CardTitle>
          <Badge variant={status === 0 ? 'default' : status === 1 ? 'success' : 'secondary'}>
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
          <span className="text-xs text-muted">截止 {new Date(Number(deadline) * 1000).toLocaleDateString()}</span>
        </div>
        <div className="flex h-2 overflow-hidden rounded-full bg-muted/15">
          <div className="bg-yes" style={{ width: `${yesPct}%` }} />
          <div className="bg-no" style={{ width: `${100 - yesPct}%` }} />
        </div>
        <div className="flex justify-between text-xs">
          <span className="text-yes font-medium">YES {yesPool.toFixed(2)} CORN</span>
          <span className="text-no font-medium">NO {noPool.toFixed(2)} CORN</span>
        </div>
        {isResolved && <p className="text-xs text-muted">结果：{result ? 'YES 胜' : 'NO 胜'}</p>}
        <div className="flex items-center gap-2">
          <Badge variant="secondary" className="text-xs">{CATEGORY_LABELS[categoryId] ?? '其他'}</Badge>
          <Button className="ml-auto" variant="outline" onClick={() => onSelect(market.id)}>查看详情</Button>
        </div>
      </CardContent>
    </Card>
  )
}

export function MarketList({ onSelect }: Props) {
  const [category, setCategory] = useState<string>('all')
  const [status, setStatus] = useState<Record<number, { loaded: boolean; visible: boolean }>>({})
  const { data: count, isLoading, isError, error } = useMarketCount()

  const total = Number(count ?? 0)
  const ids = useMemo(() => Array.from({ length: total }, (_, i) => i + 1), [total])

  const onStatus = useMemo(() => {
    return (id: number, loaded: boolean, visible: boolean) => {
      setStatus((prev) => {
        const cur = prev[id]
        if (cur && cur.loaded === loaded && cur.visible === visible) return prev
        return { ...prev, [id]: { loaded, visible } }
      })
    }
  }, [])

  if (isLoading) return <p className="text-muted">加载市场中...</p>
  if (isError) return <p className="text-no">市场数量读取失败：{String(error?.shortMessage || error?.message || error)}</p>
  if (total === 0) return <p className="text-muted">暂无市场。</p>

  const allLoaded = ids.every((id) => status[id]?.loaded)
  const visibleTotal = ids.filter((id) => status[id]?.visible).length

  return (
    <div className="space-y-4">
      <h2 className="text-xl font-bold">市场（{total}）</h2>
      <div className="flex flex-wrap gap-2">
        <Button key="all" variant={category === 'all' ? 'default' : 'outline'} size="sm" onClick={() => setCategory('all')}>
          全部
        </Button>
        {CATEGORIES.map((cat) => (
          <Button
            key={cat.id}
            variant={category === cat.id ? 'default' : 'outline'}
            size="sm"
            onClick={() => setCategory(cat.id)}
          >
            {cat.label}
          </Button>
        ))}
      </div>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {ids.map((id) => (
          <MarketRow key={id} id={id} category={category} onSelect={onSelect} onStatus={onStatus} />
        ))}
      </div>
      {allLoaded && visibleTotal === 0 && <p className="text-muted">该分类暂无市场。</p>}
    </div>
  )
}
