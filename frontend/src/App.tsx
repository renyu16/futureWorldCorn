import { useState } from 'react'
import { WalletConnect } from './components/WalletConnect'
import { MarketList } from './pages/MarketList'
import { MarketDetail } from './pages/MarketDetail'
import { CreateMarket } from './pages/CreateMarket'
import { Portfolio } from './pages/Portfolio'
import { Delegate } from './pages/Delegate'
import { Governance } from './pages/Governance'
import { HumanHouse } from './pages/HumanHouse'

function App() {
  const [page, setPage] = useState('list')
  const [selectedMarket, setSelectedMarket] = useState<number | null>(null)

  return (
    <>
      <header>
        <h1>Prediction Master</h1>
        <nav>
          <button onClick={() => setPage('list')}>Markets</button>
          <button onClick={() => setPage('create')}>Create</button>
          <button onClick={() => setPage('portfolio')}>Portfolio</button>
          <button onClick={() => setPage('delegate')}>Delegate</button>
          <button onClick={() => setPage('governance')}>Governance</button>
          <button onClick={() => setPage('humanhouse')}>Disputes</button>
        </nav>
        <WalletConnect />
      </header>
      <main>
        {page === 'list' && <MarketList onSelect={(id) => { setSelectedMarket(id); setPage('detail') }} />}
        {page === 'detail' && selectedMarket !== null && <MarketDetail marketId={selectedMarket} />}
        {page === 'create' && <CreateMarket />}
        {page === 'portfolio' && <Portfolio />}
        {page === 'delegate' && <Delegate />}
        {page === 'governance' && <Governance />}
        {page === 'humanhouse' && <HumanHouse />}
      </main>
    </>
  )
}

export default App
