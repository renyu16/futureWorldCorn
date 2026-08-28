import { useEffect, useState } from 'react'
import { Routes, Route, useNavigate, useLocation, NavLink } from 'react-router-dom'
import { useAccount, useReadContract } from 'wagmi'
import { WalletConnect } from './components/WalletConnect'
import { ToastProvider } from './components/Toast'
import { MarketList } from './pages/MarketList'
import { MarketDetail } from './pages/MarketDetail'
import { CreateMarket } from './pages/CreateMarket'
import { Portfolio } from './pages/Portfolio'
import { Delegate } from './pages/Delegate'
import { Governance } from './pages/Governance'
import { HumanHouse } from './pages/HumanHouse'
import { Settings } from './pages/Settings'
import { Button } from '@/components/ui/button'
import { TrendingUp, Menu, X } from 'lucide-react'
import { PREDICTION_MARKET_ADDRESS, predictionMarketABI } from './contracts/abi'
import { cn } from '@/lib/utils'

function NetworkBanner() {
  const { isConnected } = useAccount()
  if (isConnected) return null
  return (
    <div className="bg-amber-500/10 px-4 py-2 text-center text-sm text-amber-600">
      钱包未连接，请在右上角连接钱包
    </div>
  )
}

function ScrollToTop() {
  const { pathname } = useLocation()
  useEffect(() => { window.scrollTo({ top: 0 }) }, [pathname])
  return null
}

function App() {
  const navigate = useNavigate()
  const [mobileOpen, setMobileOpen] = useState(false)
  const { address } = useAccount()
  const { data: owner } = useReadContract({
    address: PREDICTION_MARKET_ADDRESS,
    abi: predictionMarketABI,
    functionName: 'owner',
  })
  const isOwner = address && owner ? address.toLowerCase() === (owner as string).toLowerCase() : false

  const navItems = [
    { path: '/', label: '市场' },
    ...(isOwner ? [{ path: '/create', label: '创建' }] : []),
    { path: '/portfolio', label: '投资组合' },
    { path: '/delegate', label: '委托' },
    { path: '/governance', label: '治理' },
    { path: '/humanhouse', label: '争议' },
    { path: '/settings', label: '设置' },
  ]

  return (
    <ToastProvider>
    <div className="min-h-screen bg-background">
      <ScrollToTop />
      <NetworkBanner />
      <header className="sticky top-0 z-40 border-b border-border/60 bg-card/70 backdrop-blur-xl">
        <div className="mx-auto flex h-16 max-w-6xl items-center gap-4 px-4 sm:gap-6">
          <div className="flex items-center gap-2">
            <TrendingUp className="h-6 w-6 text-primary shrink-0" />
            <h1 className="text-lg font-bold">预测大师</h1>
          </div>
          <nav className="hidden sm:flex min-w-0 flex-1 gap-1 overflow-x-auto" aria-label="主导航">
            {navItems.map((item) => (
              <NavLink
                key={item.path}
                to={item.path}
                end={item.path === '/'}
                className={({ isActive }) =>
                  cn(
                    'whitespace-nowrap rounded-md px-3 py-1.5 text-sm font-medium transition-colors',
                    isActive
                      ? 'bg-primary/10 text-primary'
                      : 'text-muted-foreground hover:bg-muted/50 hover:text-foreground'
                  )
                }
              >
                {item.label}
              </NavLink>
            ))}
          </nav>
          <div className="sm:hidden">
            <Button variant="ghost" size="sm" onClick={() => setMobileOpen(!mobileOpen)}>
              {mobileOpen ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
            </Button>
          </div>
          <WalletConnect />
        </div>
        {mobileOpen && (
          <nav className="sm:hidden border-t border-border/60 bg-card/90 backdrop-blur-xl px-4 py-2" aria-label="移动端导航">
            {navItems.map((item) => (
              <NavLink
                key={item.path}
                to={item.path}
                end={item.path === '/'}
                onClick={() => setMobileOpen(false)}
                className={({ isActive }) =>
                  cn(
                    'block whitespace-nowrap rounded-md px-3 py-2.5 text-sm font-medium transition-colors',
                    isActive
                      ? 'bg-primary/10 text-primary'
                      : 'text-muted-foreground hover:bg-muted/50 hover:text-foreground'
                  )
                }
              >
                {item.label}
              </NavLink>
            ))}
          </nav>
        )}
      </header>
      <main className="mx-auto max-w-6xl px-4 py-8">
        <Routes>
          <Route path="/" element={<MarketList onSelect={(id) => navigate(`/market/${id}`)} />} />
          <Route path="/market/:marketId" element={
            <MarketDetail
              onBack={() => navigate('/')}
              onRaiseDispute={(id) => navigate(`/humanhouse?marketId=${id}`)}
            />
          } />
          <Route path="/create" element={<CreateMarket />} />
          <Route path="/portfolio" element={<Portfolio />} />
          <Route path="/delegate" element={<Delegate />} />
          <Route path="/governance" element={<Governance />} />
          <Route path="/humanhouse" element={
            <HumanHouse
              onNavigateToMarket={(id) => navigate(`/market/${id}`)}
            />
          } />
          <Route path="/settings" element={<Settings />} />
          <Route path="*" element={
            <div className="text-center py-16 space-y-4">
              <p className="text-2xl font-bold">404</p>
              <p className="text-muted">页面不存在</p>
              <Button variant="outline" onClick={() => navigate('/')}>返回首页</Button>
            </div>
          } />
        </Routes>
      </main>
    </div>
    </ToastProvider>
  )
}

export default App
