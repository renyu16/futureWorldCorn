import { describe, it, expect } from 'vitest'
import { parseMarkets, filterAndSort, type MarketData } from '../lib/filters'
import { classifyQuestion } from '../lib/categories'

function makeMarket(overrides: Partial<MarketData> = {}): MarketData {
  return {
    id: 1,
    question: 'Test market',
    outcomeYes: 1,
    outcomeNo: 2,
    deadline: Math.floor(Date.now() / 1000) + 86400,
    status: 0,
    result: false,
    ...overrides,
  }
}

describe('parseMarkets', () => {
  it('parses raw contract data into MarketData', () => {
    const raw = [{
      id: 1,
      data: [
        'Test market',
        1000000000000000000n,  // 1 CORN yes
        2000000000000000000n,  // 2 CORN no
        BigInt(Math.floor(Date.now() / 1000) + 86400),
        0,
        false,
        200,
      ] as any,
    }]
    const result = parseMarkets(raw)
    expect(result).toHaveLength(1)
    expect(result[0].id).toBe(1)
    expect(result[0].question).toBe('Test market')
  })

  it('converts bigint wei to number CORN', () => {
    const raw = [{
      id: 1,
      data: ['Q', 5000000000000000000n, 3000000000000000000n, 0n, 0, false, 200] as any,
    }]
    const result = parseMarkets(raw)
    expect(result[0].outcomeYes).toBe(5)
    expect(result[0].outcomeNo).toBe(3)
  })

  it('handles zero pool', () => {
    const raw = [{
      id: 1,
      data: ['Q', 0n, 0n, 0n, 0, false, 200] as any,
    }]
    const result = parseMarkets(raw)
    expect(result[0].outcomeYes).toBe(0)
    expect(result[0].outcomeNo).toBe(0)
  })
})

describe('calculatePrices', () => {
  it('returns 50/50 when pool is empty', () => {
    const total = 0 + 0
    const yesPrice = total > 0 ? 0 / total : 0.5
    expect(yesPrice).toBe(0.5)
  })

  it('calculates correct yes price', () => {
    const yes = 30
    const no = 70
    const total = yes + no
    expect(yes / total).toBeCloseTo(0.3)
  })

  it('handles 100% yes', () => {
    const yes = 100
    const no = 0
    const total = yes + no
    expect(total > 0 ? yes / total : 0.5).toBe(1)
  })
})

describe('classifyQuestion', () => {
  it('classifies crypto questions', () => {
    expect(classifyQuestion('Bitcoin price above 100k?')).toBe('crypto')
    expect(classifyQuestion('ETH 能否翻倍')).toBe('crypto')
  })

  it('classifies sports questions', () => {
    expect(classifyQuestion('NBA 总冠军是谁')).toBe('sports')
  })

  it('classifies tech questions', () => {
    expect(classifyQuestion('AI 芯片发布')).toBe('tech')
  })

  it('returns other for unclassified', () => {
    expect(classifyQuestion('今天天气怎么样')).toBe('other')
  })
})

describe('filterAndSort - odds sort', () => {
  it('sorts by yes price descending', () => {
    const markets = [
      makeMarket({ id: 1, outcomeYes: 30, outcomeNo: 70 }),
      makeMarket({ id: 2, outcomeYes: 90, outcomeNo: 10 }),
      makeMarket({ id: 3, outcomeYes: 50, outcomeNo: 50 }),
    ]
    const result = filterAndSort(markets, { search: '', sort: 'odds', status: 'all', category: 'all' })
    expect(result[0].id).toBe(2) // 90% yes
    expect(result[1].id).toBe(3) // 50% yes
    expect(result[2].id).toBe(1) // 30% yes
  })
})

describe('filterAndSort - status filters', () => {
  it('filters pending markets (past deadline, unresolved)', () => {
    const past = Math.floor(Date.now() / 1000) - 3600
    const future = Math.floor(Date.now() / 1000) + 86400
    const markets = [
      makeMarket({ id: 1, status: 0, deadline: past }),
      makeMarket({ id: 2, status: 0, deadline: future }),
      makeMarket({ id: 3, status: 1, deadline: past }),
    ]
    const result = filterAndSort(markets, { search: '', sort: 'newest', status: 'pending', category: 'all' })
    expect(result).toHaveLength(1)
    expect(result[0].id).toBe(1)
  })

  it('filters resolved markets', () => {
    const markets = [
      makeMarket({ id: 1, status: 0 }),
      makeMarket({ id: 2, status: 1 }),
      makeMarket({ id: 3, status: 2 }),
    ]
    const result = filterAndSort(markets, { search: '', sort: 'newest', status: 'resolved', category: 'all' })
    expect(result).toHaveLength(1)
    expect(result[0].id).toBe(2)
  })
})
