import type { MarketTuple } from '../hooks/useMarket'
import { classifyQuestion } from './categories'

export type SortKey = 'newest' | 'pool' | 'deadline' | 'odds'
export type StatusFilter = 'all' | 'active' | 'pending' | 'resolved' | 'cancelled'

export interface FilterState {
  search: string
  sort: SortKey
  status: StatusFilter
  category: string
}

export interface MarketData {
  id: number
  question: string
  outcomeYes: number
  outcomeNo: number
  deadline: number
  status: number
  result: boolean
}

export function parseMarkets(raw: { id: number; data: MarketTuple }[]): MarketData[] {
  return raw.map(({ id, data }) => ({
    id,
    question: data[0],
    outcomeYes: Number(data[1]) / 1e18,
    outcomeNo: Number(data[2]) / 1e18,
    deadline: Number(data[3]),
    status: data[4],
    result: data[5],
  }))
}

const STATUS_MAP: Record<StatusFilter, number | null> = {
  all: null,
  active: 0,
  pending: 0,
  resolved: 1,
  cancelled: 2,
}

export function filterAndSort(markets: MarketData[], filters: FilterState): MarketData[] {
  let filtered = [...markets]

  if (filters.status !== 'all') {
    const now = Math.floor(Date.now() / 1000)
    if (filters.status === 'pending') {
      // 待结算：status=0 但 deadline 已过
      filtered = filtered.filter((m) => m.status === 0 && m.deadline <= now)
    } else if (filters.status === 'active') {
      // 进行中：status=0 且 deadline 未到
      filtered = filtered.filter((m) => m.status === 0 && m.deadline > now)
    } else {
      filtered = filtered.filter((m) => m.status === STATUS_MAP[filters.status])
    }
  }

  if (filters.category && filters.category !== 'all') {
    filtered = filtered.filter((m) => classifyQuestion(m.question) === filters.category)
  }

  if (filters.search) {
    const q = filters.search.toLowerCase()
    filtered = filtered.filter((m) => m.question.toLowerCase().includes(q))
  }

  switch (filters.sort) {
    case 'newest':
      filtered.sort((a, b) => b.id - a.id)
      break
    case 'pool':
      filtered.sort((a, b) => b.outcomeYes + b.outcomeNo - (a.outcomeYes + a.outcomeNo))
      break
    case 'deadline':
      filtered.sort((a, b) => a.deadline - b.deadline)
      break
    case 'odds':
      filtered.sort((a, b) => {
        const totalA = a.outcomeYes + a.outcomeNo
        const totalB = b.outcomeYes + b.outcomeNo
        const oddsA = totalA > 0 ? a.outcomeYes / totalA : 0
        const oddsB = totalB > 0 ? b.outcomeYes / totalB : 0
        return oddsB - oddsA
      })
      break
  }

  return filtered
}
