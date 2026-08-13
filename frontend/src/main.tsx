import React from 'react'
import ReactDOM from 'react-dom/client'
import { WagmiProvider, http } from 'wagmi'
import { RainbowKitProvider, getDefaultConfig } from '@rainbow-me/rainbowkit'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { defineChain } from 'viem'
import '@rainbow-me/rainbowkit/styles.css'
import './globals.css'
import App from './App'

const worldChain = defineChain({
  id: 4801,
  name: 'World Chain Sepolia',
  network: 'world-chain-sepolia',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: {
    default: { http: ['https://worldchain-sepolia.g.alchemy.com/public'] },
  },
  blockExplorers: {
    default: { name: 'Worldscan', url: 'https://worldchain-sepolia.explorer.alchemy.com' },
  },
})

const config = getDefaultConfig({
  appName: 'Prediction Master',
  projectId: '38cfd0c495d4727d3d7e51ec3824a052',
  chains: [worldChain],
  transports: {
    [worldChain.id]: http('https://worldchain-sepolia.g.alchemy.com/public'),
  },
})

const queryClient = new QueryClient()

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider>
          <App />
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  </React.StrictMode>,
)
