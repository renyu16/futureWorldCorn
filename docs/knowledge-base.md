# 预测大师知识库

## 一、项目全貌

### 合约关系

```
用户 ── CORN ──▶ GovCrownToken (ERC20Votes 包装)
                     │
                     ├── depositFor() → 获得 govCORN（可委托投票）
                     └── delegate()   → 授予投票权

用户 ── CORN ──▶ PredictionMarket (预测市场核心)
                     │
                     ├── createMarket()    ← onlyOwner
                     ├── bet(YES/NO)       → 下注，AMM 定价
                     ├── resolveMarket()   → 裁决（owner/resolver）
                     ├── disputeResolve()  → 争议反转结果
                     └── claimReward()     → 赢家领奖
                            │
                     OracleAdapter (Chainlink 预言机)
                            │
                     HumanHouse (社区争议裁决)
                            ├── raiseDispute()  → 付押金发起争议
                            ├── vote()          → 投票（一人一票）
                            └── executeDispute() → 通过则翻转市场结果

TimelockController (时间锁治理)
    ├── PROPOSER_ROLE → Safe 多签 (Phase 2)
    ├── EXECUTOR_ROLE → address(0)
    └── 拥有 PredictionMarket + CornToken 所有权
```

### 文件结构

| 路径 | 功能 |
|------|------|
| `src/CornToken.sol` | CORN 代币 ERC20+Permit，1B 总量 |
| `src/PredictionMarket.sol` | 预测市场核心 + `disputeResolve()` |
| `src/OracleAdapter.sol` | Chainlink 预言机适配器 |
| `src/GovCrownToken.sol` | 治理代币 ERC20Votes，包装 CORN 1:1 |
| `src/HumanHouse.sol` | 争议裁决：押金→投票→执行 |
| `src/TokenHouse.sol` | (计划中) OZ Governor |
| `test/*.t.sol` | 9 套测试，50 个用例 |
| `script/Deploy.s.sol` | 一键部署脚本 |
| `script/TransferToTimelock.s.sol` | Phase 2 Timelock 所有权转移 |
| `frontend/` | React + Vite + wagmi + RainbowKit |
| `docs/plans/` | 设计文档和实现计划 |

### 运行命令

```powershell
# 跑全部测试
.\bin\forge.exe test -vvv

# 跑单个合约测试
.\bin\forge.exe test --match-contract HumanHouse -vvv

# 启动本地链
.\bin\anvil.exe

# 前端开发
cd frontend; npm run dev
```

---

## 二、世界币 (Worldcoin / World Chain)

### 三层结构

| 层 | 说明 |
|----|------|
| **World ID** | 隐私保护的人类身份，通过 Orb 虹膜扫描验证，一次验证永久有效 |
| **World Chain** | 基于 OP Stack 的 L2，链 ID: 480（主网）/ 4801（Sepolia） |
| **WLD 代币** | 原生代币，分发给已验证用户 |

### 为什么用于本项目

```
传统治理:  1 钱包 = 1 票 → 巨鲸/女巫攻击
World ID: 1 人类 = 1 票 → 防女巫，公平投票
```

### 验证流程

```
用户 → Orb 扫描虹膜 → 生成 IrisHash → World ID 合约
                                              ↓
用户发起投票 → 提交 ZKP (root/hash/proof)  → 验证通过 → 计票
```

### 对中国的限制

- 无 Orb 投放点，中国内地无法验证
- 本项目 MVP 不强制依赖 World ID，`_verifyWorldId()` 目前返回 true
- 后续 World ID 作为可选增强（有则防女巫，无则按地址）

---

## 三、上线流程

### 合约部署

```powershell
# 准备
cp .env.example .env
# 填入：DEPLOYER_PRIVATE_KEY, FEE_COLLECTOR, KEEPER

# 部署到测试网
.\bin\forge.exe script script\Deploy.s.sol `
    --rpc-url https://worldchain-sepolia.g.alchemy.com/public `
    --broadcast --verify

# 部署到主网（确认测试网正常后）
.\bin\forge.exe script script\Deploy.s.sol `
    --rpc-url https://worldchain-mainnet.g.alchemy.com/public `
    --broadcast --verify
```

### 测试网资源

- 测试网 ETH 水龙头: https://worldchain-sepolia.faucet.xyz
- RPC: https://worldchain-sepolia.g.alchemy.com/public
- 浏览器: https://sepolia.worldscan.org

### 前端上线

```powershell
cd frontend
npm install
npm run build   # 生成 dist/
```

静态文件可托管到 Vercel / Netlify / IPFS。

### 所需资金

| 项 | 成本 |
|----|------|
| 部署 gas | $5-20（L2 便宜） |
| 合约验证 | 免费 |
| 前端托管 | Vercel 免费版 |
| 域名 | $10-15/年 |

---

## 四、演化路线

```
Phase 1 (MVP)          Phase 2 (Timelock)      Phase 3 (双院制)
┌──────────────┐       ┌──────────────────┐    ┌───────────────────┐
│ 单管理员 EOA  │─────▶│ Safe 多签         │──▶│ TokenHouse        │
│ CORN 代币     │       │ TimelockController│    │  (govCORN 投票)   │
│ 预测市场      │       │ GovCrownToken     │    │ HumanHouse        │
│ Chainlink 预言机│     │ HumanHouse        │    │  (World ID 投票)  │
└──────────────┘       └──────────────────┘    └───────────────────┘
```

### 当前状态

| Task | 状态 | 测试数 |
|------|------|--------|
| CornToken | ✅ | 10 |
| PredictionMarket | ✅ | 11+4+2 |
| OracleAdapter | ✅ | 3 |
| GovCrownToken | ✅ | 6 |
| HumanHouse | ✅ | 11 |
| Timelock 脚本 | ✅ | 1 |
| 集成测试 | ✅ | 2 |
| TokenHouse | ⏳ 待做 | 0 |
| 前端治理页 | ⏳ 待做 | 0 |
| 部署 Phase2/3 | ⏳ 待做 | 0 |
| World ID 集成 | ⏳ 待做 | 0 |
