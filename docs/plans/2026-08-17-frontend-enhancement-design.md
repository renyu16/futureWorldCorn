# Frontend Enhancement Design

Date: 2026-08-17

## Overview

Enhance the Prediction Master frontend with search/sort/filter, infinite scroll, countdown timer, and comprehensive error handling.

## Architecture Decision

**Client-side approach** — all market data loaded into memory, search/sort/filter/pagination handled in-browser. Chosen because the testnet MVP has a small market count and no on-chain search capability.

## Features

### 1. Search + Sort + Filter (MarketList)

Toolbar above market list:

```
[🔍 搜索市场...] [排序: 最新 ▼] [状态: 全部 ▼] [分类标签...]
```

- **Search**: keyword match on `question` text, case-insensitive, 300ms debounce
- **Sort**: newest / largest pool / ending soonest / highest odds
- **Status filter**: dropdown — all / active / resolved / cancelled
- **Category tags**: existing category buttons, combined with search/sort

All sorting/filtering runs on already-loaded market data in memory.

### 2. Infinite Scroll (MarketList)

- Initial render: first 12 markets
- `IntersectionObserver` on sentinel element at list bottom
- Load next 12 on scroll to bottom
- Search/sort changes reset pagination to page 1

### 3. Countdown Timer (MarketDetail)

- New `Countdown` component showing `剩余 X天 X时 X分 X秒`
- Expired/resolved markets show "已截止"
- Updates every second via `setInterval`

### 4. Error Handling

- **Toast notifications**: lightweight `<Toaster>` context, triggered on transaction submit/success/failure
- **Network disconnect**: banner at top when wallet disconnects
- **Transaction failure**: toast with revert reason
- **Load failure**: retry button on market load errors

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `hooks/useMarket.ts` | Modify | Add `useAllMarkets` bulk loader |
| `lib/filters.ts` | Create | Search/sort/filter pure functions |
| `components/Toast.tsx` | Create | Lightweight toast component + context |
| `components/Countdown.tsx` | Create | Countdown timer component |
| `components/SearchBar.tsx` | Create | Search + sort + filter toolbar |
| `pages/MarketList.tsx` | Modify | Integrate search/sort/infinite scroll |
| `pages/MarketDetail.tsx` | Modify | Integrate countdown + error retry |
| `App.tsx` | Modify | Add Toast provider + network banner |

## Data Flow

```
useAllMarkets() -> allMarkets: MarketData[]
       |
  SearchBar (searchText, sortBy, statusFilter, category)
       |
  filterAndSort(allMarkets, filters) -> filteredMarkets[]
       |
  usePagination(filteredMarkets, PAGE_SIZE=12) -> visibleMarkets[]
       |
  MarketCard[] rendered
```

## Testing

- Unit: `lib/filters.ts` pure functions
- Integration: SearchBar + MarketList interaction
- Manual: countdown accuracy, toast visibility, infinite scroll behavior
