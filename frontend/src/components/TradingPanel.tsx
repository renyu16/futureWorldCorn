import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Loader2 } from 'lucide-react'

interface Props {
  yesPool: number
  noPool: number
  feeBps: number
  userBalance: number
  userAllowance: number
  connected: boolean
  isPending?: boolean
  onBet: (outcome: number, amount: string) => void
  onApprove: (amount: string) => void
}

export function TradingPanel({ yesPool, noPool, feeBps, userBalance, userAllowance, connected, isPending, onBet, onApprove }: Props) {
  const [outcome, setOutcome] = useState<number>(0)
  const [amount, setAmount] = useState('')

  const x = parseFloat(amount) || 0
  const myPool = outcome === 0 ? yesPool : noPool
  const oppPool = outcome === 0 ? noPool : yesPool
  const fee = (oppPool * (feeBps || 0)) / 10000
  const profit = x > 0 && myPool + x > 0 ? (x * (oppPool - fee)) / (myPool + x) : 0
  const payout = x + profit
  const odds = x > 0 && profit > 0 ? 1 + profit / x : 0
  const yesPct = yesPool + noPool > 0 ? (yesPool / (yesPool + noPool)) * 100 : 50
  const noPct = 100 - yesPct

  const needsApprove = userAllowance < x
  const buttonDisabled = !connected || !amount || x <= 0 || !!isPending

  return (
    <div className="space-y-4 rounded-xl border border-border bg-card p-4">
      <div className="grid grid-cols-2 gap-2" role="group" aria-label="选择下注方向">
        <button
          data-testid="outcome-yes"
          aria-pressed={outcome === 0}
          onClick={() => setOutcome(0)}
          className={`rounded-lg border px-4 py-3 text-center transition-colors ${outcome === 0 ? 'border-yes bg-yes/10 text-yes' : 'border-border text-muted hover:border-yes/50'}`}
        >
          <div className="text-xs font-medium">YES</div>
          <div className="text-lg font-extrabold">{yesPct.toFixed(0)}%</div>
        </button>
        <button
          data-testid="outcome-no"
          aria-pressed={outcome === 1}
          onClick={() => setOutcome(1)}
          className={`rounded-lg border px-4 py-3 text-center transition-colors ${outcome === 1 ? 'border-no bg-no/10 text-no' : 'border-border text-muted hover:border-no/50'}`}
        >
          <div className="text-xs font-medium">NO</div>
          <div className="text-lg font-extrabold">{noPct.toFixed(0)}%</div>
        </button>
      </div>

      <div className="space-y-2">
        <div className="flex items-center justify-between">
          <Label htmlFor="bet-amount">数量（CORN）</Label>
          <Button
            data-testid="max-btn"
            variant="ghost"
            size="sm"
            className="h-6 px-2 text-xs"
            onClick={() => setAmount(String(Math.max(userBalance, 0).toFixed(4)))}
          >
            最大
          </Button>
        </div>
        <Input
          data-testid="bet-amount"
          id="bet-amount"
          type="number"
          placeholder="0.00"
          min="0"
          step="0.01"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
        />
      </div>

      <div className="rounded-lg bg-muted/10 p-3 text-sm" data-testid="est-payout">
        <div className="flex justify-between">
          <span className="text-muted">预估收益</span>
          <span className="font-medium text-yes">+{profit.toFixed(4)} CORN</span>
        </div>
        <div className="mt-1 flex justify-between">
          <span className="text-muted">预计回收</span>
          <span className="font-semibold">{payout.toFixed(4)} CORN</span>
        </div>
        <div className="mt-1 flex justify-between">
          <span className="text-muted">隐含赔率</span>
          <span className="font-medium">{odds.toFixed(2)}x</span>
        </div>
        <p className="mt-2 border-t border-border pt-2 text-xs text-muted">
          赢家按份额瓜分对手方资金池（平台扣 {(feeBps / 100).toFixed(2)}% 手续费），对手盘不足时收益有限。
        </p>
      </div>

      <Button
        className="w-full"
        disabled={buttonDisabled}
        onClick={() => (needsApprove ? onApprove(amount) : onBet(outcome, amount))}
      >
        {isPending ? <><Loader2 className="h-4 w-4 animate-spin" /> 确认中...</> : !connected ? '连接钱包后下注' : needsApprove ? '授权并下注' : outcome === 0 ? '下注 YES' : '下注 NO'}
      </Button>
    </div>
  )
}
