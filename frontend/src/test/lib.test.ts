import { describe, it, expect } from 'vitest'
import {
  calculateYesPrice,
  calculateNoPrice,
  getGovernanceStateName,
  getGovernanceStateLabel,
  getDisputeStateName,
  getDisputeStateLabel,
  calculateVotePercentage,
  getMarketStatusLabel,
  getDisputeTypeLabel,
  isNumeric,
  needsApprove,
  isValidAddress,
  truncateText,
  canPropose,
  parseBetAmount,
} from '../lib/helpers'

// ═══════════════════════════════════════════════════════════════
// 投注组合
// ═══════════════════════════════════════════════════════════════

describe('calculateYesPrice', () => {
  it('returns 0.5 when pool is empty', () => {
    expect(calculateYesPrice(0n, 0n)).toBe(0.5)
  })
  it('calculates correct yes price', () => {
    expect(calculateYesPrice(30n, 70n)).toBeCloseTo(0.3)
  })
  it('returns 1 when all yes', () => {
    expect(calculateYesPrice(100n, 0n)).toBe(1)
  })
  it('returns 0 when all no', () => {
    expect(calculateYesPrice(0n, 100n)).toBe(0)
  })
  it('handles large wei values', () => {
    const yes = 5000000000000000000n // 5 CORN
    const no = 5000000000000000000n
    expect(calculateYesPrice(yes, no)).toBe(0.5)
  })
})

describe('calculateNoPrice', () => {
  it('returns 0.5 when pool is empty', () => {
    expect(calculateNoPrice(0n, 0n)).toBe(0.5)
  })
  it('calculates correct no price', () => {
    expect(calculateNoPrice(30n, 70n)).toBeCloseTo(0.7)
  })
  it('yes + no always equals 1', () => {
    const y = calculateYesPrice(25n, 75n)
    const n = calculateNoPrice(25n, 75n)
    expect(y + n).toBeCloseTo(1)
  })
})

describe('getMarketStatusLabel', () => {
  it('returns 已结算 for status=1', () => {
    expect(getMarketStatusLabel(1, 0)).toBe('已结算')
  })
  it('returns 已取消 for status=2', () => {
    expect(getMarketStatusLabel(2, 0)).toBe('已取消')
  })
  it('returns 待结算 for status=0 with past deadline', () => {
    const pastDeadline = Math.floor(Date.now() / 1000) - 3600
    expect(getMarketStatusLabel(0, pastDeadline)).toBe('待结算')
  })
  it('returns 进行中 for status=0 with future deadline', () => {
    const futureDeadline = Math.floor(Date.now() / 1000) + 86400
    expect(getMarketStatusLabel(0, futureDeadline)).toBe('进行中')
  })
})

describe('parseBetAmount', () => {
  it('parses valid number to bigint wei', () => {
    const result = parseBetAmount('1.5')
    expect(result).toBe(1500000000000000000n)
  })
  it('returns 0n for invalid input', () => {
    expect(parseBetAmount('')).toBe(0n)
    expect(parseBetAmount('abc')).toBe(0n)
  })
  it('parses integer string', () => {
    expect(parseBetAmount('100')).toBe(100000000000000000000n)
  })
  it('parses zero', () => {
    expect(parseBetAmount('0')).toBe(0n)
  })
})

// ═══════════════════════════════════════════════════════════════
// 委托
// ═══════════════════════════════════════════════════════════════

describe('isNumeric', () => {
  it('returns true for valid numbers', () => {
    expect(isNumeric('1')).toBe(true)
    expect(isNumeric('0.5')).toBe(true)
    expect(isNumeric('100')).toBe(true)
    expect(isNumeric('0.001')).toBe(true)
  })
  it('returns false for invalid inputs', () => {
    expect(isNumeric('')).toBe(false)
    expect(isNumeric('abc')).toBe(false)
    expect(isNumeric('1.2.3')).toBe(false)
    expect(isNumeric('-1')).toBe(false)
  })
})

describe('needsApprove', () => {
  it('returns false when allowance is sufficient', () => {
    expect(needsApprove(100n, 200n)).toBe(false)
    expect(needsApprove(100n, 100n)).toBe(false)
  })
  it('returns true when allowance is insufficient', () => {
    expect(needsApprove(200n, 100n)).toBe(true)
  })
  it('returns false when deposit is zero', () => {
    expect(needsApprove(0n, 0n)).toBe(false)
  })
})

describe('isValidAddress', () => {
  it('validates correct 0x addresses', () => {
    expect(isValidAddress('0x7440503d25a38513919203e58db70d3ee14197ed')).toBe(true)
  })
  it('rejects invalid addresses', () => {
    expect(isValidAddress('')).toBe(false)
    expect(isValidAddress('0x123')).toBe(false)
    expect(isValidAddress('abc')).toBe(false)
  })
})

// ═══════════════════════════════════════════════════════════════
// 治理
// ═══════════════════════════════════════════════════════════════

describe('getGovernanceStateName', () => {
  it('maps 0 to Pending', () => expect(getGovernanceStateName(0)).toBe('Pending'))
  it('maps 1 to Active', () => expect(getGovernanceStateName(1)).toBe('Active'))
  it('maps 2 to Canceled', () => expect(getGovernanceStateName(2)).toBe('Canceled'))
  it('maps 3 to Defeated', () => expect(getGovernanceStateName(3)).toBe('Defeated'))
  it('maps 4 to Succeeded', () => expect(getGovernanceStateName(4)).toBe('Succeeded'))
  it('maps 5 to Queued', () => expect(getGovernanceStateName(5)).toBe('Queued'))
  it('maps 6 to Expired', () => expect(getGovernanceStateName(6)).toBe('Expired'))
  it('maps 7 to Executed', () => expect(getGovernanceStateName(7)).toBe('Executed'))
  it('returns Unknown for invalid state', () => expect(getGovernanceStateName(99)).toBe('Unknown'))
})

describe('getGovernanceStateLabel', () => {
  it('maps all states to Chinese', () => {
    expect(getGovernanceStateLabel('Pending')).toBe('待定')
    expect(getGovernanceStateLabel('Active')).toBe('进行中')
    expect(getGovernanceStateLabel('Canceled')).toBe('已取消')
    expect(getGovernanceStateLabel('Defeated')).toBe('已否决')
    expect(getGovernanceStateLabel('Succeeded')).toBe('已通过')
    expect(getGovernanceStateLabel('Queued')).toBe('队列中')
    expect(getGovernanceStateLabel('Expired')).toBe('已过期')
    expect(getGovernanceStateLabel('Executed')).toBe('已执行')
  })
  it('returns 未知 for unknown state', () => {
    expect(getGovernanceStateLabel('Unknown')).toBe('未知')
  })
})

describe('canPropose', () => {
  it('returns true when votes >= threshold', () => {
    expect(canPropose(1000n, 700n)).toBe(true)
    expect(canPropose(700n, 700n)).toBe(true)
  })
  it('returns false when votes < threshold', () => {
    expect(canPropose(700n, 1000n)).toBe(false)
  })
  it('returns false when votes is undefined', () => {
    expect(canPropose(undefined, 100n)).toBe(false)
  })
  it('returns false when threshold is undefined', () => {
    expect(canPropose(100n, undefined)).toBe(false)
  })
})

describe('truncateText', () => {
  it('returns original text if shorter than max', () => {
    expect(truncateText('hello', 100)).toBe('hello')
  })
  it('truncates long text with ellipsis', () => {
    expect(truncateText('a'.repeat(200), 100)).toBe('a'.repeat(100) + '…')
  })
  it('handles exact length', () => {
    expect(truncateText('a'.repeat(100), 100)).toBe('a'.repeat(100))
  })
})

// ═══════════════════════════════════════════════════════════════
// 争议
// ═══════════════════════════════════════════════════════════════

describe('getDisputeStateName', () => {
  it('maps 0 to Active', () => expect(getDisputeStateName(0)).toBe('Active'))
  it('maps 1 to Succeeded', () => expect(getDisputeStateName(1)).toBe('Succeeded'))
  it('maps 2 to Defeated', () => expect(getDisputeStateName(2)).toBe('Defeated'))
  it('returns Unknown for invalid state', () => expect(getDisputeStateName(99)).toBe('Unknown'))
})

describe('getDisputeStateLabel', () => {
  it('maps Active to 进行中', () => expect(getDisputeStateLabel('Active')).toBe('进行中'))
  it('maps Succeeded to 已通过', () => expect(getDisputeStateLabel('Succeeded')).toBe('已通过'))
  it('maps Defeated to 已驳回', () => expect(getDisputeStateLabel('Defeated')).toBe('已驳回'))
  it('returns 未知 for unknown', () => expect(getDisputeStateLabel('Unknown')).toBe('未知'))
})

describe('getDisputeTypeLabel', () => {
  it('maps 0 to 预言机结果', () => expect(getDisputeTypeLabel(0)).toBe('预言机结果'))
  it('maps 1 to 市场内容', () => expect(getDisputeTypeLabel(1)).toBe('市场内容'))
  it('returns 未知 for unknown type', () => expect(getDisputeTypeLabel(99)).toBe('未知'))
})

describe('calculateVotePercentage', () => {
  it('returns 50/50 when no votes', () => {
    const r = calculateVotePercentage(0, 0)
    expect(r.yesPercent).toBe(50)
    expect(r.noPercent).toBe(50)
  })
  it('calculates correct percentages', () => {
    const r = calculateVotePercentage(70, 30)
    expect(r.yesPercent).toBe(70)
    expect(r.noPercent).toBe(30)
  })
  it('handles all yes votes', () => {
    const r = calculateVotePercentage(100, 0)
    expect(r.yesPercent).toBe(100)
    expect(r.noPercent).toBe(0)
  })
  it('handles all no votes', () => {
    const r = calculateVotePercentage(0, 100)
    expect(r.yesPercent).toBe(0)
    expect(r.noPercent).toBe(100)
  })
  it('rounds correctly for odd totals', () => {
    const r = calculateVotePercentage(1, 2)
    expect(r.yesPercent + r.noPercent).toBe(100)
  })
})
