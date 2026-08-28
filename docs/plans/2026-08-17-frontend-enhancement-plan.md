# Frontend Enhancement Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add search/sort/filter, infinite scroll, countdown timer, and comprehensive error handling to the Prediction Master frontend.

**Architecture:** Pure client-side approach. All market data loaded into memory via `useAllMarkets` hook. Search/sort/filter applied as pure functions. Infinite scroll via IntersectionObserver. Lightweight toast system for notifications.

**Tech Stack:** React 18, wagmi v2, viem, Tailwind CSS 4, lucide-react icons, no new dependencies.

---

### Task 1: Create filter/sort utility functions

**Files:**
- Create: `frontend/src/lib/filters.ts`

**Step 1: Create pure filter/sort functions**

```typescript
import type { MarketTuple } from '../hooks/useMarket'

export type SortKey = 'newest' | 'pool' | 'deadline' | 'odds'
export type StatusFilter = 'all' | 'active' | 'resolved' | 'cancelled'

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

export function parseMarkets(raw: Array<{ id: number; data: MarketTuple }>): MarketData[] {
  return raw
    .filter((r) => r.data)
    .map(({ id, data }) => ({
      id,
      question: data[0],
      outcomeYes: Number(data[1]) / 1e18,
      outcomeNo: Number(data[2]) / 1e18,
      deadline: Number(data[3]),
      status: data[4] as number,
      result: data[5] as boolean,
    }))
}

export function filterAndSort(markets: MarketData[], filters: FilterState): MarketData[] {
  let result = markets

  // Status filter
  if (filters.status !== 'all') {
    const statusMap: Record<string, number> = { active: 0, resolved: 1, cancelled: 2 }
    result = result.filter((m) => m.status === statusMap[filters.status])
  }

  // Category filter
  if (filters.category && filters.category !== 'all') {
    const { classifyQuestion } = require('./categories')
    result = result.filter((m) => classifyQuestion(m.question) === filters.category)
  }

  // Search
  if (filters.search.trim()) {
    const q = filters.search.trim().toLowerCase()
    result = result.filter((m) => m.question.toLowerCase().includes(q))
  }

  // Sort
  switch (filters.sort) {
    case 'newest':
      result = [...result].sort((a, b) => b.id - a.id)
      break
    case 'pool':
      result = [...result].sort((a, b) => (b.outcomeYes + b.outcomeNo) - (a.outcomeYes + a.outcomeNo))
      break
    case 'deadline':
      result = [...result].sort((a, b) => a.deadline - b.deadline)
      break
    case 'odds': {
      const now = Math.floor(Date.now() / 1000)
      result = [...result].sort((a, b) => {
        const aActive = a.status === 0 && a.deadline > now
        const bActive = b.status === 0 && b.deadline > now
        if (aActive !== bActive) return aActive ? -1 : 1
        const aOdds = a.outcomeYes > 0 ? (a.outcomeYes + a.outcomeNo) / a.outcomeYes : 0
        const bOdds = b.outcomeYes > 0 ? (b.outcomeYes + b.outcomeNo) / b.outcomeYes : 0
        return bOdds - aOdds
      })
      break
    }
  }

  return result
}
```

**Step 2: Verify it compiles**

Run: `cd frontend && npx tsc --noEmit`
Expected: No errors

---

### Task 2: Create Toast notification system

**Files:**
- Create: `frontend/src/components/Toast.tsx`

**Step 1: Build lightweight Toast component**

```tsx
import { createContext, useCallback, useContext, useEffect, useState } from 'react'
import { X, CheckCircle, AlertCircle, Info } from 'lucide-react'

type ToastType = 'success' | 'error' | 'info'

interface Toast {
  id: number
  message: string
  type: ToastType
}

interface ToastContextValue {
  toast: (message: string, type?: ToastType) => void
}

const ToastContext = createContext<ToastContextValue>({ toast: () => {} })

export function useToast() {
  return useContext(ToastContext)
}

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([])
  const [nextId, setNextId] = useState(0)

  const toast = useCallback((message: string, type: ToastType = 'info') => {
    const id = nextId
    setNextId((n) => n + 1)
    setToasts((prev) => [...prev, { id, message, type }])
  }, [nextId])

  useEffect(() => {
    if (toasts.length === 0) return
    const timer = setTimeout(() => {
      setToasts((prev) => prev.slice(1))
    }, 4000)
    return () => clearTimeout(timer)
  }, [toasts])

  const dismiss = (id: number) => setToasts((prev) => prev.filter((t) => t.id !== id))

  const icons = {
    success: <CheckCircle className="h-4 w-4 text-yes" />,
    error: <AlertCircle className="h-4 w-4 text-no" />,
    info: <Info className="h-4 w-4 text-primary" />,
  }

  return (
    <ToastContext.Provider value={{ toast }}>
      {children}
      <div className="pointer-events-none fixed bottom-4 right-4 z-50 flex flex-col gap-2">
        {toasts.map((t) => (
          <div
            key={t.id}
            className="pointer-events-auto flex items-center gap-3 rounded-lg border border-border bg-card px-4 py-3 shadow-lg animate-in slide-in-from-bottom-2"
          >
            {icons[t.type]}
            <span className="max-w-xs text-sm">{t.message}</span>
            <button onClick={() => dismiss(t.id)} className="ml-2 text-muted hover:text-foreground">
              <X className="h-3 w-3" />
            </button>
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  )
}
```

---

### Task 3: Create Countdown component

**Files:**
- Create: `frontend/src/components/Countdown.tsx`

**Step 1: Build countdown timer**

```tsx
import { useEffect, useState } from 'react'

interface Props {
  deadline: number // unix timestamp seconds
}

export function Countdown({ deadline }: Props) {
  const [remaining, setRemaining] = useState(() => Math.max(0, deadline * 1000 - Date.now()))

  useEffect(() => {
    if (remaining <= 0) return
    const timer = setInterval(() => {
      const diff = deadline * 1000 - Date.now()
      if (diff <= 0) {
        setRemaining(0)
        clearInterval(timer)
      } else {
        setRemaining(diff)
      }
    }, 1000)
    return () => clearInterval(timer)
  }, [deadline])

  if (remaining <= 0) {
    return <span className="text-muted">已截止</span>
  }

  const days = Math.floor(remaining / 86400000)
  const hours = Math.floor((remaining % 86400000) / 3600000)
  const minutes = Math.floor((remaining % 3600000) / 60000)
  const seconds = Math.floor((remaining % 60000) / 1000)

  const parts = [
    days > 0 && `${days}天`,
    `${hours}时`,
    `${minutes}分`,
    `${seconds}秒`,
  ].filter(Boolean)

  return (
    <div className="flex items-center gap-1.5 text-sm font-medium">
      <span className="inline-block h-2 w-2 animate-pulse rounded-full bg-yes" />
      <span>剩余 {parts.join(' ')}</span>
    </div>
  )
}
```

---

### Task 4: Create SearchBar component

**Files:**
- Create: `frontend/src/components/SearchBar.tsx`

**Step 1: Build search/sort/filter toolbar**

```tsx
import { Search, ChevronDown } from 'lucide-react'
import type { SortKey, StatusFilter, FilterState } from '../lib/filters'

interface Props {
  filters: FilterState
  onChange: (filters: FilterState) => void
  totalCount: number
  filteredCount: number
}

const SORT_OPTIONS: { value: SortKey; label: string }[] = [
  { value: 'newest', label: '最新' },
  { value: 'pool', label: '资金池最大' },
  { value: 'deadline', label: '即将截止' },
  { value: 'odds', label: '赔率最高' },
]

const STATUS_OPTIONS: { value: StatusFilter; label: string }[] = [
  { value: 'all', label: '全部' },
  { value: 'active', label: '进行中' },
  { value: 'resolved', label: '已结算' },
  { value: 'cancelled', label: '已取消' },
]

export function SearchBar({ filters, onChange, totalCount, filteredCount }: Props) {
  return (
    <div className="flex flex-wrap items-center gap-3">
      <div className="relative min-w-[200px] flex-1">
        <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted" />
        <input
          type="text"
          value={filters.search}
          onChange={(e) => onChange({ ...filters, search: e.target.value })}
          placeholder="搜索市场..."
          className="h-10 w-full rounded-lg border border-border bg-card pl-9 pr-3 text-sm placeholder:text-muted focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
        />
      </div>

      <div className="relative">
        <select
          value={filters.sort}
          onChange={(e) => onChange({ ...filters, sort: e.target.value as SortKey })}
          className="h-10 appearance-none rounded-lg border border-border bg-card pl-3 pr-8 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
        >
          {SORT_OPTIONS.map((opt) => (
            <option key={opt.value} value={opt.value}>{opt.label}</option>
          ))}
        </select>
        <ChevronDown className="pointer-events-none absolute right-2 top-1/2 h-4 w-4 -translate-y-1/2 text-muted" />
      </div>

      <div className="relative">
        <select
          value={filters.status}
          onChange={(e) => onChange({ ...filters, status: e.target.value as StatusFilter })}
          className="h-10 appearance-none rounded-lg border border-border bg-card pl-3 pr-8 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
        >
          {STATUS_OPTIONS.map((opt) => (
            <option key={opt.value} value={opt.value}>{opt.label}</option>
          ))}
        </select>
        <ChevronDown className="pointer-events-none absolute right-2 top-1/2 h-4 w-4 -translate-y-1/2 text-muted" />
      </div>

      {filteredCount < totalCount && (
        <span className="text-xs text-muted">
          显示 {filteredCount}/{totalCount} 个市场
        </span>
      )}
    </div>
  )
}
```

---

### Task 5: Add useAllMarkets hook

**Files:**
- Modify: `frontend/src/hooks/useMarket.ts`

**Step 1: Add bulk market loading hook**

Append to existing file:

```typescript
export function useAllMarkets() {
  const { data: count, isLoading, isError, error, refetch } = useMarketCount()
  const total = Number(count ?? 0)
  const ids = Array.from({ length: total }, (_, i) => i + 1)

  // This returns the count + individual loading states
  // MarketList will still use useMarketTuple per item but manage state centrally
  return { total, isLoading, isError, error, refetch }
}
```

---

### Task 6: Refactor MarketList with search/sort/infinite scroll

**Files:**
- Modify: `frontend/src/pages/MarketList.tsx`

**Step 1: Rewrite MarketList**

Replace the entire `MarketList` component. Key changes:
- Add `FilterState` with `useState`
- Load all markets via existing `useMarketTuple` pattern but store in a central `allMarkets` state
- Apply `filterAndSort` on every render
- Slice filtered results for infinite scroll (PAGE_SIZE = 12)
- Add `IntersectionObserver` via `useRef` + `useEffect` on sentinel div
- Render `SearchBar` above the grid
- When `filters` change, reset `visibleCount` to PAGE_SIZE

The component structure:

```tsx
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useMarketCount, useMarketTuple } from '../hooks/useMarket'
import { filterAndSort, type FilterState } from '../lib/filters'
import { parseMarkets } from '../lib/filters'
import { SearchBar } from '../components/SearchBar'
// ... existing imports

const PAGE_SIZE = 12

export function MarketList({ onSelect }: Props) {
  const [filters, setFilters] = useState<FilterState>({
    search: '', sort: 'newest', status: 'all', category: 'all',
  })
  const [visibleCount, setVisibleCount] = useState(PAGE_SIZE)
  const sentinelRef = useRef<HTMLDivElement>(null)

  // ... existing market loading logic (keep TrendingMarket, MarketRow, etc.)

  // After all markets loaded, apply filters
  const filtered = useMemo(() => filterAndSort(allMarkets, filters), [allMarkets, filters])
  const visible = filtered.slice(0, visibleCount)
  const hasMore = visibleCount < filtered.length

  // Reset on filter change
  useEffect(() => { setVisibleCount(PAGE_SIZE) }, [filters])

  // Infinite scroll observer
  useEffect(() => {
    if (!sentinelRef.current || !hasMore) return
    const observer = new IntersectionObserver(
      (entries) => { if (entries[0].isIntersecting) setVisibleCount((c) => c + PAGE_SIZE) },
      { rootMargin: '200px' }
    )
    observer.observe(sentinelRef.current)
    return () => observer.disconnect()
  }, [hasMore])

  return (
    <div className="space-y-4">
      <TrendingMarket count={total} onSelect={onSelect} />
      <h2 className="text-xl font-bold">市场（{total}）</h2>
      <SearchBar
        filters={filters}
        onChange={setFilters}
        totalCount={total}
        filteredCount={filtered.length}
      />
      {/* Category buttons - kept as-is, sync with filters.category */}
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {visible.map((m) => (
          <MarketCard key={m.id} market={m} onSelect={onSelect} />
        ))}
      </div>
      {hasMore && <div ref={sentinelRef} className="h-10" />}
      {!hasMore && filtered.length > 0 && <p className="text-center text-sm text-muted">已加载全部</p>}
      {filtered.length === 0 && <p className="text-muted">没有匹配的市场。</p>}
    </div>
  )
}
```

---

### Task 7: Add countdown to MarketDetail

**Files:**
- Modify: `frontend/src/pages/MarketDetail.tsx`

**Step 1: Import and render Countdown**

Add import:
```tsx
import { Countdown } from '@/components/Countdown'
```

After the deadline display line (around line 106), add:
```tsx
{isOpen && <Countdown deadline={Number(deadline)} />}
```

---

### Task 8: Add Toast + network banner to App

**Files:**
- Modify: `frontend/src/App.tsx`

**Step 1: Wrap app with ToastProvider**

```tsx
import { ToastProvider, useToast } from './components/Toast'
import { useAccount } from 'wagmi' // already imported

function NetworkBanner() {
  const { isConnected } = useAccount()
  if (isConnected) return null
  return (
    <div className="bg-amber-500/10 px-4 py-2 text-center text-sm text-amber-600">
      钱包未连接，请在右上角连接钱包
    </div>
  )
}

// In render:
<ToastProvider>
  <div className="min-h-screen bg-background">
    <NetworkBanner />
    <header>...</header>
    <main>...</main>
  </div>
</ToastProvider>
```

---

### Task 9: Wire Toast into transaction flows

**Files:**
- Modify: `frontend/src/pages/MarketDetail.tsx`
- Modify: `frontend/src/pages/CreateMarket.tsx`
- Modify: `frontend/src/pages/Delegate.tsx`
- Modify: `frontend/src/pages/Governance.tsx`
- Modify: `frontend/src/pages/HumanHouse.tsx`

**Step 1: Add toast to each transaction handler**

Pattern for each file — add `useToast()` and call `toast('交易已提交', 'info')` / `toast('交易成功', 'success')` / `toast('交易失败: ' + reason, 'error')` in appropriate places.

Example in MarketDetail `handleBet`:
```tsx
const { toast } = useToast()

const handleBet = async (outcome: number, amt: string) => {
  if (!address) return
  const parsed = BigInt(Math.floor(parseFloat(amt) * 1e18))
  if (parsed <= 0n) return
  toast('交易已提交，请等待确认...', 'info')
  // ... existing approve/bet logic
  // On error: toast('交易失败', 'error')
}
```

---

### Task 10: Add error retry to MarketDetail

**Files:**
- Modify: `frontend/src/pages/MarketDetail.tsx`

**Step 1: Add retry button on error states**

Replace error/loading states:
```tsx
if (isLoading) return <p className="text-muted">加载市场中...</p>
if (!market) return (
  <div className="space-y-2">
    <p className="text-muted">未找到市场</p>
    <Button variant="outline" size="sm" onClick={onBack}>返回</Button>
  </div>
)
```

---

### Task 11: Build and verify

**Step 1: Run TypeScript check**
Run: `cd frontend && npx tsc --noEmit`
Expected: No errors

**Step 2: Run dev server**
Run: `cd frontend && npm run dev`
Expected: Server starts on localhost:5173

**Step 3: Manual verification**
- Type in search box → market list filters
- Change sort dropdown → list reorders
- Change status dropdown → list filters
- Scroll to bottom → more markets load
- Open market detail → countdown ticking
- Check toast appears on actions

---

## Commit Plan

After each task completes and compiles:
```
1. feat: add filter/sort utility functions
2. feat: add toast notification system
3. feat: add countdown component
4. feat: add search bar toolbar
5. feat: add useAllMarkets hook
6. feat: refactor MarketList with search/sort/infinite scroll
7. feat: add countdown to MarketDetail
8. feat: add toast provider and network banner to App
9. feat: wire toast into transaction flows
10. feat: add error retry to MarketDetail
11. chore: verify build
```
