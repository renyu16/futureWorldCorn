import { useEffect, useRef } from 'react'
import { Search, ChevronDown } from 'lucide-react'
import { Input } from '@/components/ui/input'
import type { FilterState, SortKey, StatusFilter } from '../lib/filters'

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
  { value: 'pending', label: '待结算' },
  { value: 'resolved', label: '已结算' },
  { value: 'cancelled', label: '已取消' },
]

function Dropdown({
  value,
  options,
  onChange,
}: {
  value: string
  options: { value: string; label: string }[]
  onChange: (v: string) => void
}) {
  return (
    <div className="relative">
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="h-10 appearance-none rounded-md border border-border bg-card px-3 pr-8 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
      >
        {options.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
      <ChevronDown className="pointer-events-none absolute right-2 top-1/2 h-4 w-4 -translate-y-1/2 text-muted" />
    </div>
  )
}

export function SearchBar({ filters, onChange, totalCount, filteredCount }: Props) {
  const timerRef = useRef<ReturnType<typeof setTimeout>>()
  const inputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    return () => clearTimeout(timerRef.current)
  }, [])

  const update = (patch: Partial<FilterState>) => {
    onChange({ ...filters, ...patch })
  }

  const onSearchChange = (raw: string) => {
    clearTimeout(timerRef.current)
    timerRef.current = setTimeout(() => {
      update({ search: raw })
    }, 300)
  }

  return (
    <div className="flex flex-wrap items-center gap-3">
      <div className="relative min-w-[200px] flex-1">
        <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted" />
        <Input
          ref={inputRef}
          defaultValue={filters.search}
          onChange={(e) => onSearchChange(e.target.value)}
          placeholder="搜索市场..."
          className="pl-9"
        />
      </div>
      <Dropdown value={filters.sort} options={SORT_OPTIONS} onChange={(v) => update({ sort: v as SortKey })} />
      <Dropdown
        value={filters.status}
        options={STATUS_OPTIONS}
        onChange={(v) => update({ status: v as StatusFilter })}
      />
      {filteredCount < totalCount && (
        <span className="whitespace-nowrap text-sm text-muted">
          显示 {filteredCount}/{totalCount} 个市场
        </span>
      )}
    </div>
  )
}
