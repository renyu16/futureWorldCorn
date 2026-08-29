/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** 目标链 ID：4801 = World Chain Sepolia 测试网（默认），480 = World Chain 主网 */
  readonly VITE_CHAIN_ID?: string
  /** 链显示名（缺省按 CHAIN_ID 映射） */
  readonly VITE_CHAIN_NAME?: string
  /** RPC URL（缺省按链使用 Alchemy 公网节点） */
  readonly VITE_RPC_URL?: string
  /** 区块浏览器（缺省按链映射） */
  readonly VITE_EXPLORER_URL?: string
  /** WalletConnect Cloud Project ID（https://cloud.walletconnect.com 免费注册） */
  readonly VITE_PROJECT_ID?: string
  /** 合约地址覆盖（不设置时用 src/config.ts 内置双链地址表） */
  readonly VITE_CORN_TOKEN_ADDRESS?: string
  readonly VITE_PREDICTION_MARKET_ADDRESS?: string
  readonly VITE_ORACLE_ADAPTER_ADDRESS?: string
  readonly VITE_GOV_CORN_TOKEN_ADDRESS?: string
  readonly VITE_TOKEN_HOUSE_ADDRESS?: string
  readonly VITE_HUMAN_HOUSE_ADDRESS?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}