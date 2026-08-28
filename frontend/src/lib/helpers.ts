export function isNumeric(v: string): boolean {
  return v !== '' && /^\d*\.?\d*$/.test(v)
}

export function parseBetAmount(v: string): bigint {
  if (!isNumeric(v)) return 0n
  return BigInt(Math.floor(parseFloat(v) * 1e18))
}

export function needsApprove(amount: bigint, allowance: bigint): boolean {
  return amount > 0n && amount > allowance
}

export function isValidAddress(v: string): boolean {
  return /^0x[a-fA-F0-9]{40}$/.test(v)
}

export function truncateText(text: string, max: number): string {
  return text.length > max ? text.slice(0, max) + '…' : text
}

export function canPropose(userVotes: bigint | undefined, threshold: bigint | undefined): boolean {
  if (userVotes === undefined || threshold === undefined) return false
  return userVotes >= threshold
}

export function getMarketStatusLabel(status: number, deadline: number): string {
  if (status === 1) return '已结算'
  if (status === 2) return '已取消'
  if (status === 0 && deadline <= Math.floor(Date.now() / 1000)) return '待结算'
  return '进行中'
}

export function getDisputeTypeLabel(type: number): string {
  const types: Record<number, string> = { 0: '预言机结果', 1: '市场内容' }
  return types[type] ?? '未知'
}

export function calculateYesPrice(yes: bigint, no: bigint): number {
  const total = yes + no
  if (total === 0n) return 0.5
  return Number(yes) / Number(total)
}

export function calculateNoPrice(yes: bigint, no: bigint): number {
  return 1 - calculateYesPrice(yes, no)
}

const GOVERNANCE_STATE_NAMES: Record<number, string> = {
  0: 'Pending',
  1: 'Active',
  2: 'Canceled',
  3: 'Defeated',
  4: 'Succeeded',
  5: 'Queued',
  6: 'Expired',
  7: 'Executed',
}

const GOVERNANCE_STATE_LABELS: Record<string, string> = {
  Pending: '待定',
  Active: '进行中',
  Canceled: '已取消',
  Defeated: '已否决',
  Succeeded: '已通过',
  Queued: '队列中',
  Expired: '已过期',
  Executed: '已执行',
}

export function getGovernanceStateName(state: number): string {
  return GOVERNANCE_STATE_NAMES[state] ?? 'Unknown'
}

export function getGovernanceStateLabel(stateName: string): string {
  return GOVERNANCE_STATE_LABELS[stateName] ?? '未知'
}

const DISPUTE_STATE_NAMES: Record<number, string> = {
  0: 'Active',
  1: 'Succeeded',
  2: 'Defeated',
}

const DISPUTE_STATE_LABELS: Record<string, string> = {
  Active: '进行中',
  Succeeded: '已通过',
  Defeated: '已驳回',
}

export function getDisputeStateName(state: number): string {
  return DISPUTE_STATE_NAMES[state] ?? 'Unknown'
}

export function getDisputeStateLabel(stateName: string): string {
  return DISPUTE_STATE_LABELS[stateName] ?? '未知'
}

export function calculateVotePercentage(
  yesVotes: number,
  noVotes: number
): { yesPercent: number; noPercent: number } {
  const total = yesVotes + noVotes
  if (total === 0) return { yesPercent: 50, noPercent: 50 }
  return {
    yesPercent: Math.round((yesVotes / total) * 100),
    noPercent: Math.round((noVotes / total) * 100),
  }
}
