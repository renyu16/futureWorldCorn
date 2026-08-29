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
import {
  CHAIN_ID,
  CHAIN_NAME,
  RPC_URL,
  EXPLORER_URL,
  NATIVE_CURRENCY_NAME,
  NATIVE_CURRENCY_SYMBOL,
  PROJECT_ID,
} from './config'

function getRpcUrl(): string {
  try {
    return localStorage.getItem('app_rpc_url') || RPC_URL
  } catch {
    return RPC_URL
  }
}

const rpcUrl = getRpcUrl()

const worldChain = defineChain({
  id: CHAIN_ID,
  name: CHAIN_NAME,
  network: CHAIN_ID === 480 ? 'world-chain' : 'world-chain-sepolia',
  nativeCurrency: { name: NATIVE_CURRENCY_NAME, symbol: NATIVE_CURRENCY_SYMBOL, decimals: 18 },
  rpcUrls: {
    default: { http: [rpcUrl] },
  },
  blockExplorers: {
    default: { name: 'Worldscan', url: EXPLORER_URL },
  },
})

const config = getDefaultConfig({
  appName: '预测大师',
  projectId: PROJECT_ID,
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
