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
