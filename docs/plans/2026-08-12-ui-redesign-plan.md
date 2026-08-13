# UI 重构实现计划 - shadcn/ui + Tailwind（浅色 Worldcoin 风）

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将前端 7 个页面从内联 style 重构为 Tailwind v4 + shadcn/ui 浅色 Worldcoin 风设计系统。

**Architecture:** 引入 Tailwind v4（@tailwindcss/vite 插件，CSS-first）+ shadcn/ui（Radix 组件源码 copy 到 src/components/ui/）。建立 design token + cn() 工具，逐页迁移，最后用现有 Playwright verify-ui 脚本回归。

**Tech Stack:** Tailwind CSS v4, shadcn/ui (Radix UI + CVA), lucide-react, clsx, tailwind-merge, class-variance-authority

**设计文档:** `docs/plans/2026-08-12-ui-redesign-design.md`

---

## Task 1: 安装依赖与配置 Tailwind v4

**Files:**
- Modify: `frontend/package.json`
- Create: `frontend/src/globals.css`
- Modify: `frontend/vite.config.ts`
- Modify: `frontend/tsconfig.json`
- Modify: `frontend/tsconfig.app.json`（若存在；否则 tsconfig.json）
- Create: `frontend/src/lib/utils.ts`

**Step 1: 安装依赖**

Run（workdir=frontend）:
```
npm install tailwindcss @tailwindcss/vite clsx tailwind-merge class-variance-authority lucide-react @radix-ui/react-slot @radix-ui/react-tabs @radix-ui/react-dialog @radix-ui/react-select @radix-ui/react-label --no-audit --no-fund
```
Expected: added packages, no errors（allow-scripts warning 可忽略）

**Step 2: 配置 vite 插件 + path alias**

Replace `frontend/vite.config.ts`:
```ts
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import path from 'path'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
})
```

**Step 3: 配置 tsconfig paths**

Modify `frontend/tsconfig.json` — add to `compilerOptions`:
```json
    "baseUrl": ".",
    "paths": { "@/*": ["./src/*"] }
```

**Step 4: 创建 globals.css（Tailwind v4 指令 + design tokens）**

Create `frontend/src/globals.css`:
```css
@import "tailwindcss";

@theme {
  --color-background: #fafafa;
  --color-card: #ffffff;
  --color-primary: #617bff;
  --color-yes: #16a34a;
  --color-no: #dc2626;
  --color-foreground: #0a0a0a;
  --color-muted: #737373;
  --color-border: #e5e5e5;
  --radius: 0.75rem;
}

body {
  background-color: var(--color-background);
  color: var(--color-foreground);
}
```

**Step 5: 在 main.tsx 引入 globals.css**

Modify `frontend/src/main.tsx` — add at top (after other imports):
```ts
import './globals.css'
```

**Step 6: 创建 cn() 工具**

Create `frontend/src/lib/utils.ts`:
```ts
import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
```

**Step 7: 验证 build**

Run: `npm run build`
Expected: tsc + vite build 通过（页面样式暂无变化，Tailwind 已生效）

**Step 8: Commit**

```bash
git add frontend/package.json frontend/vite.config.ts frontend/tsconfig.json frontend/src/globals.css frontend/src/main.tsx frontend/src/lib/utils.ts
git commit -m "frontend: setup Tailwind v4 + shadcn/ui base (deps, alias, tokens, cn util)"
```

---

## Task 2: 添加 shadcn 基础组件（button/card/badge/input/label/tabs）

**Files:**
- Create: `frontend/src/components/ui/button.tsx`
- Create: `frontend/src/components/ui/card.tsx`
- Create: `frontend/src/components/ui/badge.tsx`
- Create: `frontend/src/components/ui/input.tsx`
- Create: `frontend/src/components/ui/label.tsx`
- Create: `frontend/src/components/ui/tabs.tsx`
- Create: `frontend/src/components/ui/select.tsx`
- Create: `frontend/src/components/ui/dialog.tsx`

**Step 1: 创建 button.tsx**

Create `frontend/src/components/ui/button.tsx`:
```tsx
import * as React from 'react'
import { Slot } from '@radix-ui/react-slot'
import { cva, type VariantProps } from 'class-variance-authority'
import { cn } from '@/lib/utils'

const buttonVariants = cva(
  'inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary disabled:pointer-events-none disabled:opacity-50',
  {
    variants: {
      variant: {
        default: 'bg-primary text-white hover:bg-primary/90',
        destructive: 'bg-no text-white hover:bg-no/90',
        outline: 'border border-border bg-card hover:bg-muted/10 text-foreground',
        secondary: 'bg-muted/10 text-foreground hover:bg-muted/20',
        ghost: 'hover:bg-muted/10',
        link: 'text-primary underline-offset-4 hover:underline',
      },
      size: {
        default: 'h-10 px-4 py-2',
        sm: 'h-9 rounded-md px-3',
        lg: 'h-11 rounded-md px-8',
        icon: 'h-10 w-10',
      },
    },
    defaultVariants: { variant: 'default', size: 'default' },
  }
)

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : 'button'
    return <Comp className={cn(buttonVariants({ variant, size, className }))} ref={ref} {...props} />
  }
)
Button.displayName = 'Button'

export { Button, buttonVariants }
```

**Step 2: 创建 card.tsx**

Create `frontend/src/components/ui/card.tsx`:
```tsx
import * as React from 'react'
import { cn } from '@/lib/utils'

const Card = React.forwardRef<HTMLDivElement, React.HTMLAttributes<HTMLDivElement>>(
  ({ className, ...props }, ref) => (
    <div ref={ref} className={cn('rounded-xl border border-border bg-card text-foreground shadow-sm', className)} {...props} />
  )
)
Card.displayName = 'Card'

const CardHeader = React.forwardRef<HTMLDivElement, React.HTMLAttributes<HTMLDivElement>>(
  ({ className, ...props }, ref) => (
    <div ref={ref} className={cn('flex flex-col space-y-1.5 p-6', className)} {...props} />
  )
)
CardHeader.displayName = 'CardHeader'

const CardTitle = React.forwardRef<HTMLDivElement, React.HTMLAttributes<HTMLHeadingElement>>(
  ({ className, ...props }, ref) => (
    <div ref={ref} className={cn('font-semibold leading-none tracking-tight', className)} {...props} />
  )
)
CardTitle.displayName = 'CardTitle'

const CardDescription = React.forwardRef<HTMLDivElement, React.HTMLAttributes<HTMLParagraphElement>>(
  ({ className, ...props }, ref) => (
    <div ref={ref} className={cn('text-sm text-muted', className)} {...props} />
  )
)
CardDescription.displayName = 'CardDescription'

const CardContent = React.forwardRef<HTMLDivElement, React.HTMLAttributes<HTMLDivElement>>(
  ({ className, ...props }, ref) => (
    <div ref={ref} className={cn('p-6 pt-0', className)} {...props} />
  )
)
CardContent.displayName = 'CardContent'

const CardFooter = React.forwardRef<HTMLDivElement, React.HTMLAttributes<HTMLDivElement>>(
  ({ className, ...props }, ref) => (
    <div ref={ref} className={cn('flex items-center p-6 pt-0', className)} {...props} />
  )
)
CardFooter.displayName = 'CardFooter'

export { Card, CardHeader, CardFooter, CardTitle, CardDescription, CardContent }
```

**Step 3: 创建 badge.tsx**

Create `frontend/src/components/ui/badge.tsx`:
```tsx
import * as React from 'react'
import { cva, type VariantProps } from 'class-variance-authority'
import { cn } from '@/lib/utils'

const badgeVariants = cva(
  'inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-semibold transition-colors',
  {
    variants: {
      variant: {
        default: 'border-transparent bg-primary text-white',
        secondary: 'border-transparent bg-muted/15 text-muted',
        success: 'border-transparent bg-yes text-white',
        destructive: 'border-transparent bg-no text-white',
        outline: 'text-foreground border-border',
      },
    },
    defaultVariants: { variant: 'default' },
  }
)

export interface BadgeProps
  extends React.HTMLAttributes<HTMLDivElement>,
    VariantProps<typeof badgeVariants> {}

function Badge({ className, variant, ...props }: BadgeProps) {
  return <div className={cn(badgeVariants({ variant }), className)} {...props} />
}

export { Badge, badgeVariants }
```

**Step 4: 创建 input.tsx, label.tsx**

Create `frontend/src/components/ui/input.tsx`:
```tsx
import * as React from 'react'
import { cn } from '@/lib/utils'

const Input = React.forwardRef<HTMLInputElement, React.InputHTMLAttributes<HTMLInputElement>>(
  ({ className, ...props }, ref) => (
    <input ref={ref} className={cn('flex h-10 w-full rounded-md border border-border bg-card px-3 py-2 text-sm ring-offset-background placeholder:text-muted focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary disabled:cursor-not-allowed disabled:opacity-50', className)} {...props} />
  )
)
Input.displayName = 'Input'

export { Input }
```

Create `frontend/src/components/ui/label.tsx`:
```tsx
import * as React from 'react'
import * as LabelPrimitive from '@radix-ui/react-label'
import { cn } from '@/lib/utils'

const Label = React.forwardRef<
  React.ElementRef<typeof LabelPrimitive.Root>,
  React.ComponentPropsWithoutRef<typeof LabelPrimitive.Root>
>(({ className, ...props }, ref) => (
  <LabelPrimitive.Root ref={ref} className={cn('text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70', className)} {...props} />
))
Label.displayName = LabelPrimitive.Root.displayName

export { Label }
```

**Step 5: 创建 tabs.tsx**

Create `frontend/src/components/ui/tabs.tsx`:
```tsx
import * as React from 'react'
import * as TabsPrimitive from '@radix-ui/react-tabs'
import { cn } from '@/lib/utils'

const Tabs = TabsPrimitive.Root

const TabsList = React.forwardRef<
  React.ElementRef<typeof TabsPrimitive.List>,
  React.ComponentPropsWithoutRef<typeof TabsPrimitive.List>
>(({ className, ...props }, ref) => (
  <TabsPrimitive.List ref={ref} className={cn('inline-flex h-10 items-center justify-center rounded-lg bg-muted/10 p-1 text-muted', className)} {...props} />
))
TabsList.displayName = TabsPrimitive.List.displayName

const TabsTrigger = React.forwardRef<
  React.ElementRef<typeof TabsPrimitive.Trigger>,
  React.ComponentPropsWithoutRef<typeof TabsPrimitive.Trigger>
>(({ className, ...props }, ref) => (
  <TabsPrimitive.Trigger ref={ref} className={cn('inline-flex items-center justify-center whitespace-nowrap rounded-md px-3 py-1.5 text-sm font-medium ring-offset-background transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary disabled:pointer-events-none disabled:opacity-50 data-[state=active]:bg-card data-[state=active]:text-foreground data-[state=active]:shadow-sm', className)} {...props} />
))
TabsTrigger.displayName = TabsPrimitive.Trigger.displayName

const TabsContent = React.forwardRef<
  React.ElementRef<typeof TabsPrimitive.Content>,
  React.ComponentPropsWithoutRef<typeof TabsPrimitive.Content>
>(({ className, ...props }, ref) => (
  <TabsPrimitive.Content ref={ref} className={cn('mt-2 ring-offset-background focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary', className)} {...props} />
))
TabsContent.displayName = TabsPrimitive.Content.displayName

export { Tabs, TabsList, TabsTrigger, TabsContent }
```

**Step 6: 创建 select.tsx 和 dialog.tsx**

Create `frontend/src/components/ui/select.tsx`:
```tsx
import * as React from 'react'
import * as SelectPrimitive from '@radix-ui/react-select'
import { Check, ChevronDown } from 'lucide-react'
import { cn } from '@/lib/utils'

const Select = SelectPrimitive.Root
const SelectGroup = SelectPrimitive.Group
const SelectValue = SelectPrimitive.Value

const SelectTrigger = React.forwardRef<
  React.ElementRef<typeof SelectPrimitive.Trigger>,
  React.ComponentPropsWithoutRef<typeof SelectPrimitive.Trigger>
>(({ className, children, ...props }, ref) => (
  <SelectPrimitive.Trigger ref={ref} className={cn('flex h-10 w-full items-center justify-between rounded-md border border-border bg-card px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary disabled:cursor-not-allowed disabled:opacity-50', className)} {...props}>
    {children}
    <SelectPrimitive.Icon asChild><ChevronDown className="h-4 w-4 opacity-50" /></SelectPrimitive.Icon>
  </SelectPrimitive.Trigger>
))
SelectTrigger.displayName = SelectPrimitive.Trigger.displayName

const SelectContent = React.forwardRef<
  React.ElementRef<typeof SelectPrimitive.Content>,
  React.ComponentPropsWithoutRef<typeof SelectPrimitive.Content>
>(({ className, children, position = 'popper', ...props }, ref) => (
  <SelectPrimitive.Portal>
    <SelectPrimitive.Content ref={ref} className={cn('relative z-50 max-h-96 min-w-[8rem] overflow-hidden rounded-md border border-border bg-card text-foreground shadow-md', position === 'popper' && 'data-[side=bottom]:translate-y-1', className)} position={position} {...props}>
      <SelectPrimitive.Viewport className={cn('p-1', position === 'popper' && 'h-[var(--radix-select-trigger-height)] w-full min-w-[var(--radix-select-trigger-width)]')}>{children}</SelectPrimitive.Viewport>
    </SelectPrimitive.Content>
  </SelectPrimitive.Portal>
))
SelectContent.displayName = SelectPrimitive.Content.displayName

const SelectItem = React.forwardRef<
  React.ElementRef<typeof SelectPrimitive.Item>,
  React.ComponentPropsWithoutRef<typeof SelectPrimitive.Item>
>(({ className, children, ...props }, ref) => (
  <SelectPrimitive.Item ref={ref} className={cn('relative flex w-full cursor-default select-none items-center rounded-sm py-1.5 pl-8 pr-2 text-sm outline-none focus:bg-muted/10 data-[disabled]:pointer-events-none data-[disabled]:opacity-50', className)} {...props}>
    <span className="absolute left-2 flex h-3.5 w-3.5 items-center justify-center"><SelectPrimitive.ItemIndicator><Check className="h-4 w-4" /></SelectPrimitive.ItemIndicator></span>
    <SelectPrimitive.ItemText>{children}</SelectPrimitive.ItemText>
  </SelectPrimitive.Item>
))
SelectItem.displayName = SelectPrimitive.Item.displayName

export { Select, SelectGroup, SelectValue, SelectTrigger, SelectContent, SelectItem }
```

Create `frontend/src/components/ui/dialog.tsx`:
```tsx
import * as React from 'react'
import * as DialogPrimitive from '@radix-ui/react-dialog'
import { X } from 'lucide-react'
import { cn } from '@/lib/utils'

const Dialog = DialogPrimitive.Root
const DialogTrigger = DialogPrimitive.Trigger
const DialogPortal = DialogPrimitive.Portal
const DialogClose = DialogPrimitive.Close

const DialogOverlay = React.forwardRef<
  React.ElementRef<typeof DialogPrimitive.Overlay>,
  React.ComponentPropsWithoutRef<typeof DialogPrimitive.Overlay>
>(({ className, ...props }, ref) => (
  <DialogPrimitive.Overlay ref={ref} className={cn('fixed inset-0 z-50 bg-black/50 data-[state=open]:animate-in data-[state=closed]:animate-out', className)} {...props} />
))
DialogOverlay.displayName = DialogPrimitive.Overlay.displayName

const DialogContent = React.forwardRef<
  React.ElementRef<typeof DialogPrimitive.Content>,
  React.ComponentPropsWithoutRef<typeof DialogPrimitive.Content>
>(({ className, children, ...props }, ref) => (
  <DialogPortal>
    <DialogOverlay />
    <DialogPrimitive.Content ref={ref} className={cn('fixed left-[50%] top-[50%] z-50 grid w-full max-w-lg translate-x-[-50%] translate-y-[-50%] gap-4 border border-border bg-card p-6 shadow-lg rounded-xl', className)} {...props}>
      {children}
      <DialogPrimitive.Close className="absolute right-4 top-4 rounded-sm opacity-70 ring-offset-background transition-opacity hover:opacity-100 focus:outline-none">
        <X className="h-4 w-4" /><span className="sr-only">Close</span>
      </DialogPrimitive.Close>
    </DialogPrimitive.Content>
  </DialogPortal>
))
DialogContent.displayName = DialogPrimitive.Content.displayName

const DialogHeader = ({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) => (
  <div className={cn('flex flex-col space-y-1.5 text-center sm:text-left', className)} {...props} />
)
DialogHeader.displayName = 'DialogHeader'

const DialogTitle = React.forwardRef<
  React.ElementRef<typeof DialogPrimitive.Title>,
  React.ComponentPropsWithoutRef<typeof DialogPrimitive.Title>
>(({ className, ...props }, ref) => (
  <DialogPrimitive.Title ref={ref} className={cn('text-lg font-semibold leading-none tracking-tight', className)} {...props} />
))
DialogTitle.displayName = DialogPrimitive.Title.displayName

const DialogDescription = React.forwardRef<
  React.ElementRef<typeof DialogPrimitive.Description>,
  React.ComponentPropsWithoutRef<typeof DialogPrimitive.Description>
>(({ className, ...props }, ref) => (
  <DialogPrimitive.Description ref={ref} className={cn('text-sm text-muted', className)} {...props} />
))
DialogDescription.displayName = DialogPrimitive.Description.displayName

export { Dialog, DialogPortal, DialogOverlay, DialogTrigger, DialogClose, DialogContent, DialogHeader, DialogTitle, DialogDescription }
```

**Step 7: 验证 build**

Run: `npm run build`
Expected: 通过

**Step 8: Commit**

```bash
git add frontend/src/components/ui/
git commit -m "frontend: add shadcn/ui base components (button/card/badge/input/label/tabs/select/dialog)"
```

---

## Task 3: 重构 App 布局与 Header（Tabs 导航）

**Files:**
- Modify: `frontend/src/App.tsx`

**Step 1: 用 Tabs + header 重写 App**

Replace `frontend/src/App.tsx`:
```tsx
import { useState } from 'react'
import { WalletConnect } from './components/WalletConnect'
import { MarketList } from './pages/MarketList'
import { MarketDetail } from './pages/MarketDetail'
import { CreateMarket } from './pages/CreateMarket'
import { Portfolio } from './pages/Portfolio'
import { Delegate } from './pages/Delegate'
import { Governance } from './pages/Governance'
import { HumanHouse } from './pages/HumanHouse'
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { TrendingUp } from 'lucide-react'

function App() {
  const [page, setPage] = useState('list')
  const [selectedMarket, setSelectedMarket] = useState<number | null>(null)

  const navItems = [
    { id: 'list', label: 'Markets' },
    { id: 'create', label: 'Create' },
    { id: 'portfolio', label: 'Portfolio' },
    { id: 'delegate', label: 'Delegate' },
    { id: 'governance', label: 'Governance' },
    { id: 'humanhouse', label: 'Disputes' },
  ]

  return (
    <div className="min-h-screen bg-background">
      <header className="sticky top-0 z-40 border-b border-border bg-card/80 backdrop-blur">
        <div className="mx-auto flex h-16 max-w-6xl items-center gap-6 px-4">
          <div className="flex items-center gap-2">
            <TrendingUp className="h-6 w-6 text-primary" />
            <h1 className="text-lg font-bold">Prediction Master</h1>
          </div>
          <Tabs value={page} onValueChange={setPage} className="flex-1">
            <TabsList>
              {navItems.map((item) => (
                <TabsTrigger key={item.id} value={item.id}>{item.label}</TabsTrigger>
              ))}
            </TabsList>
          </Tabs>
          <WalletConnect />
        </div>
      </header>
      <main className="mx-auto max-w-6xl px-4 py-8">
        {page === 'list' && <MarketList onSelect={(id) => { setSelectedMarket(id); setPage('detail') }} />}
        {page === 'detail' && selectedMarket !== null && <MarketDetail marketId={selectedMarket} />}
        {page === 'create' && <CreateMarket />}
        {page === 'portfolio' && <Portfolio />}
        {page === 'delegate' && <Delegate />}
        {page === 'governance' && <Governance />}
        {page === 'humanhouse' && <HumanHouse />}
      </main>
    </div>
  )
}

export default App
```

**Step 2: 验证 build**

Run: `npm run build`
Expected: 通过

**Step 3: Commit**

```bash
git add frontend/src/App.tsx
git commit -m "frontend: redesign header layout with Tabs navigation"
```

---

## Task 4: 重构 MarketList（响应式网格卡片）

**Files:**
- Modify: `frontend/src/pages/MarketList.tsx`

**Step 1: 用 Card + Badge 重写**

Replace `frontend/src/pages/MarketList.tsx`:
```tsx
import { useMarketCount, useMarketTuple } from '../hooks/useMarket'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'

interface Props {
  onSelect: (id: number) => void
}

function MarketCard({ id, onSelect }: { id: number; onSelect: (id: number) => void }) {
  const { data: market, isLoading } = useMarketTuple(id)

  if (isLoading) return <Card className="animate-pulse"><CardContent className="h-40" /></Card>
  if (!market) return null

  const [question, outcomeYes, outcomeNo, deadline, status, result] = market
  const statusLabel = ['Open', 'Resolved', 'Cancelled'][status as number] ?? 'Unknown'
  const yesPool = Number(outcomeYes) / 1e18
  const noPool = Number(outcomeNo) / 1e18
  const deadlineStr = new Date(Number(deadline) * 1000).toLocaleString()
  const totalPool = yesPool + noPool
  const yesPct = totalPool > 0 ? (yesPool / totalPool) * 100 : 50

  return (
    <Card>
      <CardHeader>
        <div className="flex items-start justify-between gap-2">
          <CardTitle className="text-base">{question}</CardTitle>
          <Badge variant={status === 0 ? 'default' : status === 1 ? 'success' : 'secondary'}>
            {statusLabel}
          </Badge>
        </div>
      </CardHeader>
      <CardContent className="space-y-3">
        <p className="text-xs text-muted">Deadline: {deadlineStr}</p>
        {status === 1 && <p className="text-xs text-muted">Result: {result ? 'YES Won' : 'NO Won'}</p>}
        <div className="flex h-2 overflow-hidden rounded-full bg-muted/15">
          <div className="bg-yes" style={{ width: `${yesPct}%` }} />
          <div className="bg-no" style={{ width: `${100 - yesPct}%` }} />
        </div>
        <div className="flex justify-between text-xs">
          <span className="text-yes font-medium">YES {yesPool.toFixed(2)}</span>
          <span className="text-no font-medium">NO {noPool.toFixed(2)}</span>
        </div>
        <Button className="w-full" variant="outline" onClick={() => onSelect(id)}>View Details</Button>
      </CardContent>
    </Card>
  )
}

export function MarketList({ onSelect }: Props) {
  const { data: count, isLoading, isError, error } = useMarketCount()

  if (isLoading) return <p className="text-muted">Loading markets...</p>
  if (isError) return <p className="text-no">Market count error: {String(error?.shortMessage || error?.message || error)}</p>

  const total = Number(count ?? 0)
  if (total === 0) return <p className="text-muted">No markets yet.</p>

  const ids = Array.from({ length: total }, (_, i) => i + 1)

  return (
    <div className="space-y-4">
      <h2 className="text-xl font-bold">Markets ({total})</h2>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {ids.map((id) => <MarketCard key={id} id={id} onSelect={onSelect} />)}
      </div>
    </div>
  )
}
```

**Step 2: 验证 build**

Run: `npm run build`
Expected: 通过

**Step 3: Commit**

```bash
git add frontend/src/pages/MarketList.tsx
git commit -m "frontend: redesign MarketList with responsive grid cards"
```

---

## Task 5: 重构 MarketDetail

**Files:**
- Modify: `frontend/src/pages/MarketDetail.tsx`

**Step 1: 用 Card + Input + Select + Button 重写**

Replace `frontend/src/pages/MarketDetail.tsx`:
```tsx
import { useState } from 'react'
import { useAccount, useReadContract } from 'wagmi'
import { useMarketTuple, useWriteBet, useWriteClaimReward, useWriteResolveMarket } from '../hooks/useMarket'
import { useTokenBalance, useTokenAllowance, useWriteApprove } from '../hooks/useToken'
import { CORN_TOKEN_ADDRESS, cornTokenABI, PREDICTION_MARKET_ADDRESS, predictionMarketABI } from '../contracts/abi'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Badge } from '@/components/ui/badge'
import { ArrowLeft } from 'lucide-react'

interface Props {
  marketId: number
}

export function MarketDetail({ marketId }: Props) {
  const { address } = useAccount()
  const { data: market, isLoading } = useMarketTuple(marketId)
  const { data: balance } = useTokenBalance(address)
  const { data: allowance } = useTokenAllowance(address, PREDICTION_MARKET_ADDRESS)
  const { data: owner } = useReadContract({
    address: PREDICTION_MARKET_ADDRESS,
    abi: predictionMarketABI,
    functionName: 'owner',
  })
  const { writeContract: approve } = useWriteApprove()
  const { writeContract: bet } = useWriteBet()
  const { writeContract: claim } = useWriteClaimReward()
  const { writeContract: resolve } = useWriteResolveMarket()

  const [betAmount, setBetAmount] = useState('')
  const [selectedOutcome, setSelectedOutcome] = useState<number>(0)

  if (isLoading) return <p className="text-muted">Loading market...</p>
  if (!market) return <p className="text-muted">Market not found</p>

  const [question, outcomeYes, outcomeNo, deadline, status, result] = market
  const statusLabel = ['Open', 'Resolved', 'Cancelled'][status as number] ?? 'Unknown'
  const yesPool = Number(outcomeYes) / 1e18
  const noPool = Number(outcomeNo) / 1e18
  const userBalance = balance ? Number(balance) / 1e18 : 0
  const userAllowance = allowance ? Number(allowance) / 1e18 : 0
  const isOpen = status === 0
  const isResolved = status === 1
  const amountParsed = BigInt(Math.floor(parseFloat(betAmount || '0') * 1e18))
  const isOwner = address && owner ? address.toLowerCase() === (owner as string).toLowerCase() : false
  const deadlinePassed = Number(deadline) * 1000 < Date.now()

  const handleBet = async () => {
    if (!address || amountParsed <= 0n) return
    if (userAllowance < parseFloat(betAmount || '0')) {
      approve({
        address: CORN_TOKEN_ADDRESS, abi: cornTokenABI, functionName: 'approve',
        args: [PREDICTION_MARKET_ADDRESS, amountParsed],
      })
    } else {
      bet({
        address: PREDICTION_MARKET_ADDRESS, abi: predictionMarketABI, functionName: 'bet',
        args: [BigInt(marketId), selectedOutcome, amountParsed],
      })
    }
  }

  const handleClaim = async () => {
    claim({
      address: PREDICTION_MARKET_ADDRESS, abi: predictionMarketABI, functionName: 'claimReward',
      args: [BigInt(marketId)],
    })
  }

  const handleResolve = async (win: boolean) => {
    resolve({
      address: PREDICTION_MARKET_ADDRESS, abi: predictionMarketABI, functionName: 'resolveMarket',
      args: [BigInt(marketId), win],
    })
  }

  return (
    <div className="space-y-4">
      <Button variant="ghost" size="sm" onClick={() => window.history.back()} className="text-muted">
        <ArrowLeft className="mr-2 h-4 w-4" /> Back
      </Button>
      <Card>
        <CardHeader>
          <div className="flex items-start justify-between gap-2">
            <CardTitle className="text-xl">{question}</CardTitle>
            <Badge variant={status === 0 ? 'default' : status === 1 ? 'success' : 'secondary'}>{statusLabel}</Badge>
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-2 gap-4 text-sm">
            <div><span className="text-muted">Deadline:</span><br />{new Date(Number(deadline) * 1000).toLocaleString()}</div>
            <div><span className="text-muted">Result:</span><br />{isResolved ? (result ? 'YES Won' : 'NO Won') : '-'}</div>
            <div><span className="text-yes font-medium">YES Pool:</span><br />{yesPool.toFixed(4)} CORN</div>
            <div><span className="text-no font-medium">NO Pool:</span><br />{noPool.toFixed(4)} CORN</div>
          </div>
          <div className="rounded-lg bg-muted/10 p-3 text-sm">
            <span className="text-muted">Your Balance:</span> <span className="font-medium">{userBalance.toFixed(4)} CORN</span>
          </div>

          {isOpen && address && (
            <div className="space-y-3 border-t border-border pt-4">
              <h3 className="font-semibold">Place Bet</h3>
              <div className="space-y-2">
                <Label>Outcome</Label>
                <Select value={String(selectedOutcome)} onValueChange={(v) => setSelectedOutcome(Number(v))}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="0">YES</SelectItem>
                    <SelectItem value="1">NO</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label>Amount (CORN)</Label>
                <Input type="number" placeholder="0.00" min="0" step="0.01" value={betAmount} onChange={(e) => setBetAmount(e.target.value)} />
              </div>
              <Button className="w-full" disabled={!betAmount || parseFloat(betAmount) <= 0} onClick={handleBet}>
                {userAllowance < parseFloat(betAmount || '0') ? 'Approve' : 'Bet'}
              </Button>
            </div>
          )}

          {isResolved && address && (
            <div className="border-t border-border pt-4">
              <Button className="w-full" onClick={handleClaim}>Claim Reward</Button>
            </div>
          )}

          {isOpen && isOwner && deadlinePassed && (
            <div className="space-y-3 border-t border-border pt-4">
              <h3 className="font-semibold">Resolve Market</h3>
              <p className="text-sm text-muted">Deadline has passed. Choose the winning outcome.</p>
              <div className="flex gap-2">
                <Button className="flex-1" variant="outline" onClick={() => handleResolve(true)}>Resolve YES Wins</Button>
                <Button className="flex-1" variant="outline" onClick={() => handleResolve(false)}>Resolve NO Wins</Button>
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
```

**Step 2: 验证 build**

Run: `npm run build`
Expected: 通过

**Step 3: Commit**

```bash
git add frontend/src/pages/MarketDetail.tsx
git commit -m "frontend: redesign MarketDetail with Card sections"
```

---

## Task 6: 重构 CreateMarket

**Files:**
- Modify: `frontend/src/pages/CreateMarket.tsx`

**Step 1: 用 Card + Input + Button 重写**

Replace `frontend/src/pages/CreateMarket.tsx`:
```tsx
import { useState } from 'react'
import { useWriteCreateMarket } from '../hooks/useMarket'
import { predictionMarketABI, PREDICTION_MARKET_ADDRESS } from '../contracts/abi'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

export function CreateMarket() {
  const { writeContract } = useWriteCreateMarket()
  const [question, setQuestion] = useState('')
  const [deadline, setDeadline] = useState('')
  const [feeBps, setFeeBps] = useState('')
  const [status, setStatus] = useState('')

  const handleCreate = async () => {
    if (!question || !deadline) return
    const deadlineUnix = BigInt(Math.floor(new Date(deadline).getTime() / 1000))
    const fee = feeBps ? Number(feeBps) : 0
    writeContract({
      address: PREDICTION_MARKET_ADDRESS, abi: predictionMarketABI, functionName: 'createMarket',
      args: [question, Number(deadlineUnix), fee],
    })
    setStatus('Transaction submitted. Check wallet to confirm.')
  }

  return (
    <Card className="max-w-2xl">
      <CardHeader>
        <CardTitle>Create Market</CardTitle>
        <CardDescription>Deploy a new prediction market on World Chain Sepolia.</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          <Label>Question</Label>
          <Input type="text" value={question} onChange={(e) => setQuestion(e.target.value)} placeholder="e.g. Will ETH reach $10k by end of 2026?" />
        </div>
        <div className="space-y-2">
          <Label>Deadline</Label>
          <Input type="datetime-local" value={deadline} onChange={(e) => setDeadline(e.target.value)} />
        </div>
        <div className="space-y-2">
          <Label>Fee (basis points, optional)</Label>
          <Input type="number" value={feeBps} onChange={(e) => setFeeBps(e.target.value)} placeholder="e.g. 250 = 2.5%" min="0" max="10000" />
        </div>
        <Button className="w-full" disabled={!question || !deadline} onClick={handleCreate}>Create Market</Button>
        {status && <p className="text-sm text-muted">{status}</p>}
      </CardContent>
    </Card>
  )
}
```

**Step 2: 验证 build**

Run: `npm run build`
Expected: 通过

**Step 3: Commit**

```bash
git add frontend/src/pages/CreateMarket.tsx
git commit -m "frontend: redesign CreateMarket form"
```

---

## Task 7: 重构 Portfolio

**Files:**
- Modify: `frontend/src/pages/Portfolio.tsx`

**Step 1: 用 Card 重写**

Replace `frontend/src/pages/Portfolio.tsx`:
```tsx
import { useAccount } from 'wagmi'
import { useMarketCount, useMarketTuple } from '../hooks/useMarket'
import { useTokenBalance } from '../hooks/useToken'
import { Card, CardContent } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'

function MarketPosition({ marketId }: { marketId: number }) {
  const { data: market } = useMarketTuple(marketId)
  if (!market) return null
  const [question, , , , status] = market
  const statusLabel = ['Open', 'Resolved', 'Cancelled'][status as number] ?? 'Unknown'
  return (
    <Card>
      <CardContent className="flex items-center justify-between p-4">
        <div>
          <p className="font-medium">{question}</p>
          <p className="text-xs text-muted">Market #{marketId}</p>
        </div>
        <Badge variant={status === 0 ? 'default' : status === 1 ? 'success' : 'secondary'}>{statusLabel}</Badge>
      </CardContent>
    </Card>
  )
}

export function Portfolio() {
  const { address } = useAccount()
  const { data: count } = useMarketCount()
  const { data: balance } = useTokenBalance(address)
  const total = Number(count ?? 0)
  const ids = Array.from({ length: total }, (_, i) => i)

  return (
    <div className="space-y-6">
      <h2 className="text-xl font-bold">Portfolio</h2>
      {address ? (
        <div className="space-y-6">
          <Card>
            <CardContent className="space-y-2 p-6">
              <div className="flex justify-between"><span className="text-muted">Wallet</span><span className="font-mono text-sm">{address}</span></div>
              <div className="flex justify-between"><span className="text-muted">CORN Balance</span><span className="font-medium">{balance ? (Number(balance) / 1e18).toFixed(4) : '0'} CORN</span></div>
            </CardContent>
          </Card>
          <div className="space-y-3">
            <h3 className="font-semibold">Your Markets</h3>
            {total === 0 ? <p className="text-muted">No markets found.</p> : ids.map((id) => <MarketPosition key={id} marketId={id} />)}
          </div>
        </div>
      ) : (
        <Card><CardContent className="p-6 text-muted">Connect your wallet to view portfolio.</CardContent></Card>
      )}
    </div>
  )
}
```

**Step 2: 验证 build**

Run: `npm run build`
Expected: 通过

**Step 3: Commit**

```bash
git add frontend/src/pages/Portfolio.tsx
git commit -m "frontend: redesign Portfolio with balance card"
```

---

## Task 8: 重构 Delegate

**Files:**
- Modify: `frontend/src/pages/Delegate.tsx`

**Step 1: 用 Card + Input + Button 重写**

Replace `frontend/src/pages/Delegate.tsx`:
```tsx
import { useState } from 'react'
import { useAccount, useReadContract, useWriteContract } from 'wagmi'
import { parseEther, formatEther } from 'viem'
import { CORN_TOKEN_ADDRESS, cornTokenABI, GOV_CORN_TOKEN_ADDRESS, govCrownTokenABI } from '../contracts/abi'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

export function Delegate() {
  const { address } = useAccount()
  const [depositAmount, setDepositAmount] = useState('')
  const [withdrawAmount, setWithdrawAmount] = useState('')
  const [delegatee, setDelegatee] = useState('')

  const { data: cornBalance, refetch: refetchCorn } = useReadContract({
    address: CORN_TOKEN_ADDRESS, abi: cornTokenABI, functionName: 'balanceOf',
    args: address ? [address] : undefined,
  })
  const { data: govCornBalance, refetch: refetchGov } = useReadContract({
    address: GOV_CORN_TOKEN_ADDRESS, abi: govCrownTokenABI, functionName: 'balanceOf',
    args: address ? [address] : undefined,
  })
  const { data: votes } = useReadContract({
    address: GOV_CORN_TOKEN_ADDRESS, abi: govCrownTokenABI, functionName: 'getVotes',
    args: address ? [address] : undefined,
  })
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: CORN_TOKEN_ADDRESS, abi: cornTokenABI, functionName: 'allowance',
    args: address ? [address, GOV_CORN_TOKEN_ADDRESS] : undefined,
  })
  const { writeContract } = useWriteContract()

  const depositAmt = parseEther(depositAmount || '0')
  const needsApprove = allowance !== undefined && depositAmt > 0n && depositAmt > (allowance as bigint)
  const refetchAll = () => { refetchCorn(); refetchGov(); refetchAllowance() }

  return (
    <div className="space-y-6">
      <h2 className="text-xl font-bold">Delegate</h2>
      {!address ? (
        <Card><CardContent className="p-6 text-muted">Connect your wallet to delegate.</CardContent></Card>
      ) : (
        <div className="space-y-6">
          <Card>
            <CardContent className="grid grid-cols-3 gap-4 p-6">
              <div><p className="text-xs text-muted">CORN Balance</p><p className="font-medium">{cornBalance ? formatEther(cornBalance as bigint) : '-'}</p></div>
              <div><p className="text-xs text-muted">govCORN Balance</p><p className="font-medium">{govCornBalance ? formatEther(govCornBalance as bigint) : '-'}</p></div>
              <div><p className="text-xs text-muted">Voting Power</p><p className="font-medium">{votes ? formatEther(votes as bigint) : '-'}</p></div>
            </CardContent>
          </Card>
          <Card>
            <CardHeader><CardTitle className="text-base">Deposit CORN → govCORN</CardTitle></CardHeader>
            <CardContent className="space-y-3">
              <div className="space-y-2">
                <Label>Amount</Label>
                <Input value={depositAmount} onChange={(e) => setDepositAmount(e.target.value)} placeholder="0.00" />
              </div>
              <div className="flex gap-2">
                <Button variant="outline" disabled={!needsApprove || depositAmt === 0n} onClick={() => writeContract({ address: CORN_TOKEN_ADDRESS, abi: cornTokenABI, functionName: 'approve', args: [GOV_CORN_TOKEN_ADDRESS, depositAmt] }, { onSuccess: () => refetchAllowance() })}>Approve</Button>
                <Button disabled={needsApprove || depositAmt === 0n} onClick={() => writeContract({ address: GOV_CORN_TOKEN_ADDRESS, abi: govCrownTokenABI, functionName: 'depositFor', args: [address, depositAmt] }, { onSuccess: () => refetchAll() })}>Deposit</Button>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardHeader><CardTitle className="text-base">Withdraw govCORN → CORN</CardTitle></CardHeader>
            <CardContent className="space-y-3">
              <div className="space-y-2">
                <Label>Amount</Label>
                <Input value={withdrawAmount} onChange={(e) => setWithdrawAmount(e.target.value)} placeholder="0.00" />
              </div>
              <Button disabled={parseEther(withdrawAmount || '0') === 0n} onClick={() => writeContract({ address: GOV_CORN_TOKEN_ADDRESS, abi: govCrownTokenABI, functionName: 'withdrawTo', args: [address, parseEther(withdrawAmount || '0')] }, { onSuccess: () => refetchAll() })}>Withdraw</Button>
            </CardContent>
          </Card>
          <Card>
            <CardHeader><CardTitle className="text-base">Delegate Voting Power</CardTitle></CardHeader>
            <CardContent className="space-y-3">
              <div className="space-y-2">
                <Label>Delegatee Address</Label>
                <Input value={delegatee} onChange={(e) => setDelegatee(e.target.value)} placeholder="0x..." className="font-mono" />
              </div>
              <Button disabled={!delegatee} onClick={() => writeContract({ address: GOV_CORN_TOKEN_ADDRESS, abi: govCrownTokenABI, functionName: 'delegate', args: [delegatee as `0x${string}`] })}>Delegate</Button>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  )
}
```

**Step 2: 验证 build**

Run: `npm run build`
Expected: 通过

**Step 3: Commit**

```bash
git add frontend/src/pages/Delegate.tsx
git commit -m "frontend: redesign Delegate with balance + action cards"
```

---

## Task 9: 重构 Governance

**Files:**
- Modify: `frontend/src/pages/Governance.tsx`

**Step 1: 用 Card + Dialog 重写**

Replace `frontend/src/pages/Governance.tsx` entirely.（此页面较长，重构要点：用 Card 展示 proposal 列表，Card + Select 投票表单，Dialog 创建 proposal。保留所有原有 useReadContract/useWriteContract 逻辑与 args 不变，仅替换 JSX 结构与 className。）

完整代码见设计文档映射。保留逻辑：proposals state、useEffect getLogs（已限 100 块）、ProposalDetail 投票、CreateProposal 表单。所有内联 style 改为 Tailwind class，所有 button 改 `<Button>`，输入改 `<Input>`，弹窗改 `<Dialog>`。

**Step 2: 验证 build**

Run: `npm run build`
Expected: 通过

**Step 3: Commit**

```bash
git add frontend/src/pages/Governance.tsx
git commit -m "frontend: redesign Governance with Card list + Dialog proposal form"
```

---

## Task 10: 重构 HumanHouse

**Files:**
- Modify: `frontend/src/pages/HumanHouse.tsx`

**Step 1: 用 Card + Input + Button + Dialog 重写**

Replace `frontend/src/pages/HumanHouse.tsx` entirely.（保留所有 hook 逻辑、MOOCK_PROOF、useEffect fetchDisputeCreatedLogs。JSX 改 Card 列表 + Card 详情 + RaiseDispute 表单。所有内联 style 改 Tailwind class。）

保留：DisputeInfo、DISPUTE_TYPE/STATE、DisputeDetail 投票/执行、RaiseDispute（deposit/allowance/approve）、HumanHouse 主组件（disputes list + loading/error）。

**Step 2: 验证 build**

Run: `npm run build`
Expected: 通过

**Step 3: Commit**

```bash
git add frontend/src/pages/HumanHouse.tsx
git commit -m "frontend: redesign HumanHouse with Card list + dispute form"
```

---

## Task 11: 最终验证与回归

**Step 1: 完整 build**

Run (workdir=frontend): `npm run build`
Expected: tsc + vite build 通过

**Step 2: 启动 dev server 跑 Playwright 回归**

Run (workdir=frontend): 先启动 `npm run dev`，再 `npm run test:ui`
Expected: 16/16 checks passed

**Step 3: 手动浏览确认无内联 style 残留**

Grep: 搜索 `style={{` 在 `frontend/src/pages` 下应无结果。

Run: `rg "style=\{\{" frontend/src/pages`
Expected: 无输出

**Step 4: Commit（如有清理）**

```bash
git add -A frontend/src
git commit -m "frontend: UI redesign complete, all pages migrated to Tailwind+shadcn"
```

---

## 验收标准

- `npm run build` 通过
- `npm run test:ui` 16/16 全绿
- `frontend/src/pages` 无内联 `style={{` 残留
- 各页面视觉统一：浅色背景、Worldcoin 蓝、Card 圆角、YES 绿 NO 红
