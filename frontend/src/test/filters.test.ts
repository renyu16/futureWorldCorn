import { describe, it, expect } from 'vitest'
import { filterAndSort, type MarketData, type FilterState } from '../lib/filters'

function makeMarket(overrides: Partial<MarketData> = {}): MarketData {
  return {
    id: 1,
    question: 'Test market',
    outcomeYes: 100,
    outcomeNo: 100,
    deadline: Math.floor(Date.now() / 1000) + 86400,
    status: 0,
    result: false,
    ...overrides,
  }
}

describe('filterAndSort', () => {
  const baseFilters: FilterState = { search: '', sort: 'newest', status: 'all', category: 'all' }

  it('returns all markets when no filters applied', () => {
    const markets = [makeMarket({ id: 1 }), makeMarket({ id: 2 })]
    const result = filterAndSort(markets, baseFilters)
    expect(result).toHaveLength(2)
  })

  it('filters by search text', () => {
    const markets = [
      makeMarket({ id: 1, question: 'Bitcoin price' }),
      makeMarket({ id: 2, question: 'Ethereum price' }),
    ]
    const result = filterAndSort(markets, { ...baseFilters, search: 'Bitcoin' })
    expect(result).toHaveLength(1)
    expect(result[0].id).toBe(1)
  })

  it('filters active markets', () => {
    const future = Math.floor(Date.now() / 1000) + 86400
    const markets = [
      makeMarket({ id: 1, status: 0, deadline: future }),
      makeMarket({ id: 2, status: 1 }),
    ]
    const result = filterAndSort(markets, { ...baseFilters, status: 'active' })
    expect(result).toHaveLength(1)
    expect(result[0].id).toBe(1)
  })

  it('sorts by newest first', () => {
    const markets = [makeMarket({ id: 1 }), makeMarket({ id: 3 }), makeMarket({ id: 2 })]
    const result = filterAndSort(markets, { ...baseFilters, sort: 'newest' })
    expect(result[0].id).toBe(3)
    expect(result[1].id).toBe(2)
    expect(result[2].id).toBe(1)
  })

  it('sorts by pool size', () => {
    const markets = [
      makeMarket({ id: 1, outcomeYes: 100, outcomeNo: 100 }),
      makeMarket({ id: 2, outcomeYes: 500, outcomeNo: 500 }),
    ]
    const result = filterAndSort(markets, { ...baseFilters, sort: 'pool' })
    expect(result[0].id).toBe(2)
  })
})
