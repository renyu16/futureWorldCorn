/**
 * 前端运行配置 —— 链 / RPC / WalletConnect / 合约地址
 *
 * 全部配置可被构建时环境变量覆盖（见 frontend/.env.example、frontend/src/vite-env.d.ts）。
 * 优先级：frontend/.env 中的 VITE_*  >  本文件内置默认值。
 *
 * 注意：本项目为纯静态站点（Vite base './'），环境变量在「构建时」注入，
 * 切换链/地址后需重新 `npm run build` 并替换部署目录的 web/ 才生效。
 *
 * ─────────────────────────────────────────────
 * 正式上线（World Chain 主网 480）切换指南：
 *   1. 复制 .env.example 为 .env
 *   2. 设 VITE_CHAIN_ID=480
 *   3. 把 480 链表中的 `0x...` 占位替换为正式部署地址（见 deploy 输出）
 *   4. 灰度前后先保留 4801 测试网验证，再切 480 重新构建
 * ─────────────────────────────────────────────
 */

/** 单个链的合约地址集合 */
export interface ChainAddresses {
  cornToken: string
  predictionMarket: string
  oracleAdapter: string
  govCornToken: string
  tokenHouse: string
  humanHouse: string
}

export const DEFAULT_CHAIN_ID = 4801

/**
 * 内置双链地址表。
 * 4801 为 World Chain Sepolia 测试网（已部署确认）。
 * 480 为 World Chain 主网占位 —— 正式上线前替换为 forge script 部署输出地址。
 */
const DEFAULT_ADDRESSES: Record<string, ChainAddresses> = {
  // World Chain Sepolia（联调 / 测试）
  4801: {
    cornToken: '0x7440503d25a38513919203e58db70d3ee14197ed',
    predictionMarket: '0x9cb69cb7da9677b3a122a6a4e402398a6df4a026',
    oracleAdapter: '0x1457eef9d78eda3e18095f3ff50e15f10764de72',
    govCornToken: '0x3F540371f5E88E3B9625b63411e4ba1FDB4702f0',
    tokenHouse: '0x70Edf96015fE901c44b6b61Ad5CcB9884B545DE9',
    humanHouse: '0xd1062855477c08bff3c852fc42844ca35db32c72',
  },
  // World Chain 主网（正式上线 TODO：替换为实际部署地址）
  480: {
    cornToken: '0x...',
    predictionMarket: '0x...',
    oracleAdapter: '0x...',
    govCornToken: '0x...',
    tokenHouse: '0x...',
    humanHouse: '0x...',
  },
}

/** 链元数据（可被环境变量覆盖的名称/浏览器） */
const CHAIN_META: Record<number, { name: string; native: string; explorer: string }> = {
  4801: {
    name: 'World Chain Sepolia',
    native: 'Ether',
    explorer: 'https://worldchain-sepolia.explorer.alchemy.com',
  },
  480: {
    name: 'World Chain',
    native: 'Ether',
    explorer: 'https://worldscan.org',
  },
}

function pickStr(key: string, fallback: string): string {
  const raw = (import.meta.env as Record<string, string | undefined>)[key]
  return raw && raw.trim() ? raw.trim() : fallback
}

function pickInt(key: string, fallback: number): number {
  const raw = (import.meta.env as Record<string, string | undefined>)[key]
  if (!raw) return fallback
  const n = Number.parseInt(raw, 10)
  return Number.isFinite(n) ? n : fallback
}

/** 目标链 ID（VITE_CHAIN_ID，默认 4801 测试网） */
export const CHAIN_ID = pickInt('VITE_CHAIN_ID', DEFAULT_CHAIN_ID)

/** 链显示名（VITE_CHAIN_NAME，默认按 CHAIN_ID 映射） */
export const CHAIN_NAME = pickStr(
  'VITE_CHAIN_NAME',
  CHAIN_META[CHAIN_ID]?.name ?? CHAIN_META[DEFAULT_CHAIN_ID].name,
)

/** 原生币名称（原生币符号固定 ETH） */
export const NATIVE_CURRENCY_NAME = CHAIN_META[CHAIN_ID]?.native ?? 'Ether'
export const NATIVE_CURRENCY_SYMBOL = 'ETH'

/** 区块浏览器（VITE_EXPLORER_URL，默认按 CHAIN_ID 映射） */
export const EXPLORER_URL = pickStr(
  'VITE_EXPLORER_URL',
  CHAIN_META[CHAIN_ID]?.explorer ?? CHAIN_META[DEFAULT_CHAIN_ID].explorer,
)

/**
 * WalletConnect Cloud Project ID（https://cloud.walletconnect.com 免费注册）。
 * 当前为开发用默认值；正式上线建议替换为自有项目 ID（VITE_PROJECT_ID）。
 */
export const PROJECT_ID = pickStr(
  'VITE_PROJECT_ID',
  '38cfd0c495d4727d3d7e51ec3824a052',
)

/** RPC URL（VITE_RPC_URL，默认按 CHAIN_ID 用 Alchemy 公网节点） */
export const RPC_URL = pickStr(
  'VITE_RPC_URL',
  CHAIN_ID === 480
    ? 'https://worldchain-mainnet.g.alchemy.com/public'
    : 'https://worldchain-sepolia.g.alchemy.com/public',
)

// 单地址环境变量覆盖表：key -> VITE_* 变量名
const ENV_OVERRIDES: Record<keyof ChainAddresses, string> = {
  cornToken: 'VITE_CORN_TOKEN_ADDRESS',
  predictionMarket: 'VITE_PREDICTION_MARKET_ADDRESS',
  oracleAdapter: 'VITE_ORACLE_ADAPTER_ADDRESS',
  govCornToken: 'VITE_GOV_CORN_TOKEN_ADDRESS',
  tokenHouse: 'VITE_TOKEN_HOUSE_ADDRESS',
  humanHouse: 'VITE_HUMAN_HOUSE_ADDRESS',
}

/** 取某一链的地址表（不做环境变量覆盖，供 getConfig/测试使用） */
export function getConfig(chainId: number): ChainAddresses {
  const cfg = DEFAULT_ADDRESSES[String(chainId)]
  if (!cfg) throw new Error(`No chain config found for chain ID ${chainId}`)
  return { ...cfg }
}

/** 当前选中链的地址：内置表 + 单地址 VITE_* 覆盖 */
export function resolveAddresses(): ChainAddresses {
  const base = getConfig(CHAIN_ID in CHAIN_META ? CHAIN_ID : DEFAULT_CHAIN_ID)
  const out: ChainAddresses = { ...base }
  ;(Object.keys(ENV_OVERRIDES) as (keyof ChainAddresses)[]).forEach((key) => {
    const raw = (import.meta.env as Record<string, string | undefined>)[ENV_OVERRIDES[key]]
    if (raw && raw.trim()) out[key] = raw.trim()
  })
  return out
}

/** 当前构建的合约地址（直接供业务读取） */
export const ADDRESSES = resolveAddresses()