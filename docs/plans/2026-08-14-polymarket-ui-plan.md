# Polymarket 风格界面渐进优化实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.
> 前置条件：设计文档 `docs/plans/2026-08-14-polymarket-ui-design.md` 已确认。在 `rz-20260814-polymarket-ui` 分支上执行（当前 `rz-20260814-android-apk` 分支仅完成 APK Task 1-4，与本计划互不影响）。

**Goal:** 在浅色 Worldcoin 主题上渐进吸收 Polymarket 设计语言：首页热门市场横向滚动区 + 市场卡片升级 + 交易页 Polymarket 下单面板。

**Architecture:** 纯前端改动。首页在 MarketList 顶部新增 TrendingMarket 聚合组件（每个市场一个独立 hook 实例上报数据，父组件排序 Top 5 渲染纯展示卡片）；交易页新增 TradingPanel 子组件，用对赌模型公式实时计算预计获得。新增 Skeleton 骨架屏组件。验证用 verify-ui.mjs 端到端断言（TDD：先加断言失败 → 实现 → 通过）。

**Tech Stack:** React 19 + TypeScript + Vite + Tailwind v4 + wagmi/viem + Playwright。

**链上赔付公式（合约 `claimReward`，用于预计获得计算）：**
- fee = losingPool × feeBps / 10000（默认 200 = 2%）
- 预估收益 = X × (losingPool − fee) / (winningPool + X)，X 为用户下注额
- 预计回收 = X + 预估收益；隐含赔率 = 1 + 预估收益 / X

---

### Task 1: Skeleton 骨架屏组件

**Files:**
- Create: `frontend/src/components/ui/skeleton.tsx`

**Step 1: 创建组件**

```tsx
export function Skeleton({ className = '' }: { className?: string }) {
  return <div className={`animate-pulse rounded-md bg-muted/20 ${className}`} />
}
```

**Step 2: 验证构建**

Run: `cd frontend; npx tsc --noEmit`
Expected: 无错误

**Step 3: Commit**

```bash
git add frontend/src/components/ui/skeleton.tsx
git commit -m "feat: add Skeleton loading component"
```

---

### Task 2: 首页热门市场横向滚动区

**Files:**
- Modify: `frontend/src/pages/MarketList.tsx`
- Test: `frontend/verify-ui.mjs`（Step 1 先加断言）

**Step 1: 先加 verify-ui 断言（预期 FAIL）**

在 verify-ui.mjs 中 `market list reads chain` 断言之后插入：

```js
  // 3a. Trending section renders with open market cards
  const trending = page.locator('main div:has-text("热门市场")').first()
  try {
    await trending.waitFor({ state: 'visible', timeout: 30000 })
    const trendingCards = await page.locator('[data-testid="trending-card"]').count()
    record('trending section renders', trendingCards > 0, `cards=${trendingCards}`)
  } catch (e) {
    record('trending section renders', false, e.message.split('\n')[0])
  }
```

Run: `cd frontend; npm run test:ui`
Expected: `FAIL  trending section renders`

**Step 2: MarketList.tsx 新增 TrendingMarket 组件**

文件顶部追加（在 `import { Badge } ...` 之后）：

```tsx
import { Skeleton } from '@/components/ui/skeleton'
import type { MarketTuple } from '../hooks/useMarket'
```

在 `MarketCard` 定义之后、`MarketList` 之前插入：

```tsx
function TrendingLoader({ id, onData }: { id: number; onData: (id: number, m: MarketTuple) => void }) {
  const { data: market } = useMarketTuple(id)
  useEffect(() => {
    if (market) onData(id, market)
  }, [market, id, onData])
  return null
}

function TrendingCard({ id, market, onSelect }: { id: number; market: MarketTuple; onSelect: (id: number) => void }) {
  const [q, outcomeYes, outcomeNo, deadline, status] = market
  const yesPool = Number(outcomeYes) / 1e18
  const noPool = Number(outcomeNo) / 1e18
  const totalPool = yesPool + noPool
  const yesPct = totalPool > 0 ? (yesPool / totalPool) * 100 : 50
  const categoryId = classifyQuestion(q)
  return (
    <button
      data-testid="trending-card"
      onClick={() => onSelect(id)}
      className="group min-w-[280px] snap-start rounded-xl border border-border bg-card p-4 text-left shadow-sm transition-all hover:-translate-y-0.5 hover:shadow-md"
    >
      <div className="mb-2 flex items-center justify-between">
        <Badge variant="secondary" className="text-xs">{CATEGORY_LABELS[categoryId] ?? '其他'}</Badge>
        <span className="text-xs text-muted">{new Date(Number(deadline) * 1000).toLocaleDateString()}</span>
      </div>
      <p className="mb-3 line-clamp-2 text-sm font-medium">{q}</p>
      <div className="flex items-baseline gap-1">
        <span className="text-4xl font-extrabold text-yes">{yesPct.toFixed(0)}%</span>
        <span className="text-xs text-muted">YES</span>
      </div>
      <div className="mt-2 text-xs text-muted">资金池 {totalPool.toFixed(2)} CORN</div>
    </button>
  )
}

function TrendingMarket({ count, onSelect }: { count: number; onSelect: (id: number) => void }) {
  const [markets, setMarkets] = useState<Record<number, MarketTuple>>({})
  const ids = useMemo(() => Array.from({ length: count }, (_, i) => i + 1), [count])

  const onData = useMemo(
    () => (id: number, m: MarketTuple) => {
      setMarkets((prev) => {
        if (prev[id] === m) return prev
        return { ...prev, [id]: m }
      })
    },
    []
  )

  const sorted = useMemo(() => {
    return Object.entries(markets)
      .map(([id, m]) => ({ id: Number(id), pool: Number(m[1]) / 1e18 + Number(m[2]) / 1e18, status: m[4] }))
      .filter((x) => x.status === 0 && x.pool > 0)
      .sort((a, b) => b.pool - a.pool)
      .slice(0, 5)
  }, [markets])

  const loading = ids.length > 0 && Object.keys(markets).length < ids.length

  return (
    <section>
      <h2 className="mb-3 text-lg font-bold">热门市场</h2>
      {loading ? (
        <div className="flex gap-4 overflow-x-auto">
          {[0, 1, 2, 3].map((i) => (
            <Skeleton key={i} className="h-40 min-w-[280px]" />
          ))}
        </div>
      ) : sorted.length > 0 ? (
        <div className="flex gap-4 overflow-x-auto pb-2 snap-x">
          {sorted.map(({ id }) => (
            <TrendingCard key={id} id={id} market={markets[id]} onSelect={onSelect} />
          ))}
        </div>
      ) : null}
    </section>
  )
}
```

**Step 3: MarketList 渲染 TrendingMarket**

在 `MarketList` 的 return 中，`<h2 className="text-xl font-bold">市场（{total}）</h2>` 之前插入：

```tsx
      <TrendingMarket count={total} onSelect={onSelect} />
```

**Step 4: 验证断言通过 + 构建**

Run: `cd frontend; npm run test:ui`
Expected: `PASS  trending section renders`，其余保持通过

Run: `cd frontend; npm run build`
Expected: 无 TS 错误

**Step 5: Commit**

```bash
git add frontend/src/pages/MarketList.tsx frontend/src/components/ui/skeleton.tsx frontend/verify-ui.mjs
git commit -m "feat: add trending market horizontal scroll section to homepage"
```

---

### Task 3: 市场卡片升级

**Files:**
- Modify: `frontend/src/pages/MarketList.tsx`

**Step 1: MarketCard 加资金池总量行 + hover 过渡 + 灰化**

将 `MarketCard` 的 Card 外层改为：

```tsx
  return (
    <Card className={`transition-all hover:-translate-y-0.5 hover:shadow-md ${isResolved ? 'opacity-70' : ''}`}>
```

在深度条之后、`<div className="flex justify-between text-xs">` 之前插入资金池总量行：

```tsx
        <div className="flex items-center justify-between text-xs">
          <span className="text-muted">资金池</span>
          <span className="font-medium">{totalPool.toFixed(2)} CORN</span>
        </div>
```

**Step 2: 验证构建 + 回归**

Run: `cd frontend; npm run test:ui`
Expected: 全部 PASS（17 + trending 1 = 18）

Run: `cd frontend; npm run build`
Expected: 无 TS 错误

**Step 3: Commit**

```bash
git add frontend/src/pages/MarketList.tsx
git commit -m "feat: enrich market card with total pool and hover polish"
```

---

### Task 4: TradingPanel 下单面板 + MarketDetail 集成

**Files:**
- Create: `frontend/src/components/TradingPanel.tsx`
- Modify: `frontend/src/pages/MarketDetail.tsx`
- Test: `frontend/verify-ui.mjs`（Step 1 先加断言）

**Step 1: 先加 verify-ui 断言（预期 FAIL）**

在 verify-ui.mjs `category filter bar renders and filters` 块之后插入：

```js
  // 3c. Trading panel on market detail (Polymarket-style YES/NO tabs + Max + estimated payout)
  await page.locator('main button:has-text("查看详情")').first().click()
  await page.locator('button:has-text("下注")').first().waitFor({ state: 'visible', timeout: 30000 })
  const yesTab = page.locator('[data-testid="outcome-yes"]')
  const noTab = page.locator('[data-testid="outcome-no"]')
  const maxBtn = page.locator('[data-testid="max-btn"]')
  record('trading panel renders', (await yesTab.count()) > 0 && (await noTab.count()) > 0 && (await maxBtn.count()) > 0)

  await maxBtn.click()
  const amountVal = await page.locator('[data-testid="bet-amount"]').inputValue()
  const payoutVisible = await page.locator('[data-testid="est-payout"]').isVisible().catch(() => false)
  record('max button fills amount and shows payout', Number(amountVal) > 0 && payoutVisible, `amount=${amountVal}`)
  await page.locator('main button:has-text("返回")').first().click()
  await page.waitForTimeout(500)
```

Run: `cd frontend; npm run test:ui`
Expected: `FAIL  trading panel renders`（此时详情页无 data-testid）

**Step 2: 创建 TradingPanel.tsx**

```tsx
import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { TrendingUp } from 'lucide-react'

interface Props {
  yesPool: number
  noPool: number
  feeBps: number
  userBalance: number
  userAllowance: number
  onBet: (outcome: number, amount: string) => void
  onApprove: (amount: string) => void
}

export function TradingPanel({ yesPool, noPool, feeBps, userBalance, userAllowance, onBet, onApprove }: Props) {
  const [outcome, setOutcome] = useState<number>(0)
  const [amount, setAmount] = useState('')

  const x = parseFloat(amount) || 0
  const myPool = outcome === 0 ? yesPool : noPool
  const oppPool = outcome === 0 ? noPool : yesPool
  const fee = (oppPool * (feeBps || 0)) / 10000
  const profit = x > 0 && myPool + x > 0 ? (x * (oppPool - fee)) / (myPool + x) : 0
  const payout = x + profit
  const odds = x > 0 && profit > 0 ? (1 + profit / x) : 0
  const yesPct = yesPool + noPool > 0 ? (yesPool / (yesPool + noPool)) * 100 : 50
  const noPct = 100 - yesPct

  const needsApprove = userAllowance < x

  return (
    <div className="space-y-4 rounded-xl border border-border bg-card p-4">
      <div className="grid grid-cols-2 gap-2">
        <button
          data-testid="outcome-yes"
          onClick={() => setOutcome(0)}
          className={`rounded-lg border px-4 py-3 text-center transition-colors ${outcome === 0 ? 'border-yes bg-yes/10 text-yes' : 'border-border text-muted hover:border-yes/50'}`}
        >
          <div className="text-xs font-medium">YES</div>
          <div className="text-lg font-extrabold">{yesPct.toFixed(0)}%</div>
        </button>
        <button
          data-testid="outcome-no"
          onClick={() => setOutcome(1)}
          className={`rounded-lg border px-4 py-3 text-center transition-colors ${outcome === 1 ? 'border-no bg-no/10 text-no' : 'border-border text-muted hover:border-no/50'}`}
        >
          <div className="text-xs font-medium">NO</div>
          <div className="text-lg font-extrabold">{noPct.toFixed(0)}%</div>
        </button>
      </div>

      <div className="space-y-2">
        <div className="flex items-center justify-between">
          <Label>数量（CORN）</Label>
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
          赢家按份额瓜分对手方资金池（平台扣 2% 手续费），对手盘不足时收益有限。
        </p>
      </div>

      <Button
        className="w-full"
        disabled={!amount || x <= 0}
        onClick={() => (needsApprove ? onApprove(amount) : onBet(outcome, amount))}
      >
        {needsApprove ? '授权' : outcome === 0 ? '下注 YES' : '下注 NO'}
      </Button>
    </div>
  )
}
```

**Step 3: MarketDetail 集成 TradingPanel**

- 解构增加 feeBps：`const [question, outcomeYes, outcomeNo, deadline, status, result, feeBps] = market`
- 顶部 import 增加 `TradingPanel`
- 删除原下注区（`isOpen && address && !deadlinePassed` 块中的 Select/Input/Button 逻辑），替换为：

```tsx
          {isOpen && address && !deadlinePassed && (
            <div className="space-y-3 border-t border-border pt-4">
              <h3 className="flex items-center gap-2 font-semibold">
                <TrendingUp className="h-4 w-4 text-primary" /> 下注
              </h3>
              <TradingPanel
                yesPool={yesPool}
                noPool={noPool}
                feeBps={Number(feeBps) || 0}
                userBalance={userBalance}
                userAllowance={userAllowance}
                onBet={(outcome, amt) =>
                  bet({
                    address: PREDICTION_MARKET_ADDRESS,
                    abi: predictionMarketABI,
                    functionName: 'bet',
                    args: [BigInt(marketId), outcome, BigInt(Math.floor(parseFloat(amt) * 1e18))],
                  })
                }
                onApprove={(amt) =>
                  approve({
                    address: CORN_TOKEN_ADDRESS,
                    abi: cornTokenABI,
                    functionName: 'approve',
                    args: [PREDICTION_MARKET_ADDRESS, BigInt(Math.floor(parseFloat(amt) * 1e18))],
                  })
                }
              />
            </div>
          )}
```

注意：原 `selectedOutcome`/`betAmount`/`handleBet`/`handleClaim` 中 `handleBet` 的 state 可移除；import 中 Select/SelectItem 等不再使用需清理（Label 仍被结算区外的"您的余额"外其它使用——检查后移除未使用的 Select 相关 import）。

**Step 4: 验证断言通过 + 构建**

Run: `cd frontend; npm run test:ui`
Expected: `PASS  trading panel renders` 与 `PASS  max button fills amount and shows payout`，其余保持通过

Run: `cd frontend; npm run build`
Expected: 无 TS 错误（若有未使用 import 报错则清理）

**Step 5: Commit**

```bash
git add frontend/src/components/TradingPanel.tsx frontend/src/pages/MarketDetail.tsx frontend/verify-ui.mjs
git commit -m "feat: add Polymarket-style trading panel with live payout estimate"
```

---

### Task 5: 全量回归 + 收尾

**Step 1: 全量验证**

Run: `cd frontend; npm run test:ui`
Expected: 全部 PASS（20 项：原 17 + trending 1 + trading panel 2）

Run: `cd frontend; npm run build`
Expected: 无 TS 错误

**Step 2: 检查 git status**

Run: `git status --short`
Expected: 无未提交改动、无泄漏文件（keystore/dist/android）

**Step 3: 合并回 main 决策（交给用户/执行者按 finishing-a-development-branch skill 决定）**

---

## 备注

- `MarketTuple` 已含 7 元素（含 feeBps，index 6），Task 4 解构需对齐
- 热门区与列表各自独立加载（各 id 一个 `useMarketTuple` hook 实例），不违反 Hooks 规则
- 预计获得为结算时近似值（假设结算前无人再下注），文案不承诺精确
- 若 `bet` 的 BigInt 转换对超大金额报错，保持现有 `Math.floor(parseFloat(...) * 1e18)` 守卫
