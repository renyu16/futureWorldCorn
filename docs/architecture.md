# 预测大师（Future World Corn）完整系统架构

## 整体架构

```
                        ┌──────────────────────┐
                        │   第三方服务（外部）   │
                        └──────────────────────┘
                                  ▲
     ┌────────────────────────────┼────────────────────────────┐
     │                            │                            │
     │  ┌─────────────┐  ┌────────┴────────┐  ┌──────────────┐│
     │  │   Alchemy    │  │  WalletConnect   │  │ Google News  ││
     │  │   RPC 节点   │  │     Cloud        │  │    RSS       ││
     │  │ (测试网/主网) │  │ (relay+API)      │  │  (新闻推送)  ││
     │  └─────────────┘  └─────────────────┘  └──────────────┘│
     │         ▲                   ▲                    ▲      │
     │         │                   │                    │      │
═════╪═════════╪═══════════════════╪════════════════════╪══════╪════
     │         │                   │                    │      │
     │  ┌──────┴───────────────────┴────────────────────┴───┐  │
     │  │         阿里云 ECS  8.141.100.69:8085              │  │
     │  │         ┌─────────────────────────────────────┐   │  │
     │  │  HTTP   │  serve.mjs (Node.js)                │   │  │
     │  │  :8085  │                                     │   │  │
     │  │         │  ├── 路径 /  → 静态前端 SPA          │   │  │
     │  │         │  │   (release/*/web/)               │   │  │
     │  │         │  │   index.html 回退支持 SPA 路由    │   │  │
     │  │         │  │                                  │   │  │
     │  │         │  └── 路径 /rpc → JSON-RPC 反代 ─────┼───┼──┤──► Alchemy
     │  │         │      POST /rpc {jsonrpc}            │   │  │    公共节点
     │  │         │      → 转发上游 Alchemy             │   │  │
     │  │         │      → 20s 超时                     │   │  │
     │  │         │      → 非 POST 返回 405             │   │  │
     │  │         └─────────────────────────────────────┘   │  │
     │  └───────────────────────────────────────────────────┘  │
     │         ▲                           ▲                   │
     │         │                           │                   │
     │    ┌────┴─────┐              ┌──────┴────────┐          │
     │    │ Web 前端  │              │  Android APK  │          │
     │    │(浏览器)   │              │  (手机客户端)  │          │
     │    │ React    │              │   Flutter      │          │
     │    │ wagmi    │              │   Reown AppKit │          │
     │    └──────────┘              └───────────────┘          │
     │         │                           │                   │
     │         │  WalletConnect / MetaMask │                   │
     │         │      WSS 深链连接         │                   │
     │         │            ┌──────────────┘                   │
     │         │            ▼                                  │
     │         │    ┌─────────────────┐                        │
     │         └───►│ MetaMask 钱包    │◄─── 深链唤起           │
     │              │ (手机/浏览器)    │     metamask://wc      │
     │              │ 负责签名+广播    │     app.link/wc        │
     │              └────────┬────────┘                        │
     │                       │ eth_sendTransaction             │
     │                       │ (通过 WalletConnect relay)      │
     │                       ▼                                 │
═════╪═════════════════════════════════════════════════════════╪════
     │              链 上（World Chain Sepolia 4801）            │
     │                       │                                 │
     │    ┌──────────────────┼──────────────────┐              │
     │    │                  ▼                  │              │
     │    │   ┌─────────────────────────────┐   │              │
     │    │   │  PredictionMarket (UUPS)    │   │              │
     │    │   │  代理 0x9cb69c...a026        │   │              │
     │    │   │  实现 0x98a0088...5162       │   │              │
     │    │   │                             │   │              │
     │    │   │  createMarket() ─── 上线市场 │   │              │
     │    │   │  bet() ──────────── 下注     │   │              │
     │    │   │  resolveMarket() ── 结算     │   │              │
     │    │   │  claimReward() ──── 领取     │   │              │
     │    │   │  disputeResolve() ─ 争议翻转 │   │              │
     │    │   └─────────────────────────────┘   │              │
     │    │              ▲                      │              │
     │    │              │ approve / transferFrom              │
     │    │   ┌─────────────────────────────┐   │              │
     │    │   │  CornToken (ERC20)          │   │              │
     │    │   │  下注代币 10亿供应量         │   │              │
     │    │   └─────────────────────────────┘   │              │
     │    │              ▲                      │              │
     │    │   ┌─────────────────────────────┐   │              │
     │    │   │  OracleAdapter              │   │              │
     │    │   │  链上读 Chainlink Feed ─────┼───┼──► Chainlink │
     │    │   │  resolveWithFeed()          │   │    Price Feed│
     │    │   │  pushResult() (手动兜底)     │   │    合约     │
     │    │   └─────────────────────────────┘   │              │
     │    │              ▲                      │              │
     │    │   ┌─────────────────────────────┐   │              │
     │    │   │  HumanHouse (争议仲裁)       │   │              │
     │    │   │  链上 World ID verifyProof ─┼───┼──► World ID  │
     │    │   │  (当前模拟，待真实集成)      │   │    Router    │
     │    │   └─────────────────────────────┘   │              │
     │    │              ▲                      │              │
     │    │   ┌─────────────────────────────┐   │              │
     │    │   │  GovCrownToken / TokenHouse  │   │              │
     │    │   │  治理：CORN→govCORN 包装     │   │              │
     │    │   │  提案投票 / Timelock 执行    │   │              │
     │    │   └─────────────────────────────┘   │              │
     │    └─────────────────────────────────────┘              │
     │                                                         │
     │   WalletConnect Cloud                                   │
     │   relay: wss://relay.walletconnect.org                  │
     │   projectId: 38cfd0c495d4727d3d7e51ec3824a052           │
     │                                                         │
════════════════════════════════════════════════════════════════════
```

## 数据流向

### ① APK/前端读市场列表
```
APK → http://8.141.100.69:8085/rpc (eth_call)
     → 阿里云 serve.mjs → Alchemy → World Chain 节点
```

### ② 用户下注
```
APK → WalletConnect relay (WSS) → MetaMask
MetaMask 签名 → eth_sendTransaction → 链上 bet()
```

### ③ 市场结算
```
Keeper → OracleAdapter.resolveWithFeed()
→ 链上读 Chainlink Price Feed → 对比阈值
→ market.resolveMarket(result)
```

### ④ 用户领取奖励
```
APK → WalletConnect relay → MetaMask 签名
→ claimReward() → CORN 转账到用户钱包
```

## 关键地址与端口

### 阿里云服务器
- `8.141.100.69:8085` — 业务端口
  - `/` — 前端静态 SPA
  - `/rpc` — JSON-RPC 反代 → Alchemy

### World Chain Sepolia (chainId 4801)
| 合约 | 地址 |
|------|------|
| PredictionMarket (proxy) | `0x9cb69cb7da9677b3a122a6a4e402398a6df4a026` |
| CornToken | `0x7440503d25a38513919203e58db70d3ee14197ed` |
| GovCrownToken | `0x3F540371f5E88E3B9625b63411e4ba1FDB4702f0` |
| TokenHouse | `0x70Edf96015fE901c44b6b61Ad5CcB9884B545DE9` |
| HumanHouse | `0xd1062855477c08bff3c852fc42844ca35db32c72` |

### WalletConnect
- relay: `wss://relay.walletconnect.org`
- API: `api.web3modal.com` (钱包列表)
- projectId: `38cfd0c495d4727d3d7e51ec3824a052`

### 第三方链上服务
- Chainlink Price Feed — keeper 配置的 feedAddr
- World ID Router — 部署时传入

## 设计特点

- **无自有后端**：所有数据读写走链上 RPC，交易签名通过 WalletConnect 交给 MetaMask
- **阿里云反代**：解决内地手机 DNS 对 alchemy.com 解析失败问题
- **预言机去中心化程度**：OracleAdapter 调用 Chainlink（链上），但触发依赖中心化 Keeper（待改进）
- **World ID**：HumanHouse 当前使用模拟证明，待真实集成
