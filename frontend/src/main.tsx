import React from 'react'
import ReactDOM from 'react-dom/client'
import { WagmiProvider, http } from 'wagmi'
import { RainbowKitProvider, getDefaultConfig } from '@rainbow-me/rainbowkit'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { HashRouter } from 'react-router-dom'
import { defineChain } from 'viem'
import '@rainbow-me/rainbowkit/styles.css'
import './globals.css'
import App from './App'
import { setupDeepLink } from './capacitor'

const DEFAULT_RPC = 'https://worldchain-sepolia.g.alchemy.com/public'

function getRpcUrl(): string {
  try {
    return localStorage.getItem('app_rpc_url') || DEFAULT_RPC
  } catch {
    return DEFAULT_RPC
  }
}

const rpcUrl = getRpcUrl()

const worldChain = defineChain({
  id: 4801,
  name: 'World Chain Sepolia',
  network: 'world-chain-sepolia',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: {
    default: { http: [rpcUrl] },
  },
  blockExplorers: {
    default: { name: 'Worldscan', url: 'https://worldchain-sepolia.explorer.alchemy.com' },
  },
})

const config = getDefaultConfig({
  appName: '预测大师',
  projectId: '38cfd0c495d4727d3d7e51ec3824a052',
  chains: [worldChain],
  transports: {
    [worldChain.id]: http(rpcUrl, { timeout: 8000 }),
  },
})

const queryClient = new QueryClient({
  defaultOptions: {
    queries: { retry: 1, retryDelay: 1000 },
  },
})

setupDeepLink()

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider>
          <HashRouter>
            <App />
          </HashRouter>
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  </React.StrictMode>,
)
