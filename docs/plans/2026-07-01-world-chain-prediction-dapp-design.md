# World Chain 预测大师 Dapp 设计文档

## 概述

在 World Chain（Worldcoin L2，OP Stack）上构建一个预测市场 Dapp，用户使用项目代币对现实事件结果下注。初期为 MVP（标准预测市场），后续演进集成 World ID 和 DAO 治理。

## 技术栈

| 层级 | 技术 |
|------|------|
| 智能合约 | Solidity + Foundry |
| 代币标准 | OpenZeppelin ERC20 + ERC20Permit |
| 预言机 | Chainlink Data Feeds / Automation |
| 前端 | React + Vite + TypeScript + wagmi + viem + RainbowKit |
| 升级方案 | UUPS Proxy (OpenZeppelin) |

## 架构

```
Frontend (React + wagmi)
       │
       ▼
World Chain (EVM L2)
  ├── CornToken (ERC20)
  ├── PredictionMarket (UUPS upgradeable)
  │     ├── MarketFactory
  │     ├── Market (per-event AMM pools)
  │     └── OracleAdapter
  └── Chainlink (Data Feeds / Automation)
```

## 智能合约设计

### CornToken

- 名称: CornToken, 符号: CORN
- 固定总量: 1,000,000,000 * 10^18
- 标准: ERC20 + ERC20Permit (EIP-2612, gasless approve)
- 预留存储槽 `__gap[50]` 供未来升级
- 初期 admin 可 mint (Phase 1 结束后锁定)
- 任何人都可 burn 自己持有的代币

### PredictionMarket

#### Market 数据结构

```solidity
struct Market {
    string question;                    // 事件描述
    uint128 outcomeYes;                 // YES 池总量
    uint128 outcomeNo;                  // NO 池总量
    uint40 deadline;                    // 截止时间
    bool resolved;                      // 是否已裁决
    bool result;                        // true = YES 赢, false = NO 赢
    SourceType sourceType;              // 预言机类型
    bytes32 feedKey;                    // Data Feed / 自定义源标识
    uint256 threshold;                  // 阈值（用于场景 A）
    uint16 feeBps;                      // 本市场手续费（覆盖默认值）
}
```

#### 核心函数

- `createMarket(question, deadline, sourceType, feedKey, threshold, feeBps)` — 创建市场
- `bet(marketId, outcome, amount)` — 授权后下注
- `resolveMarket(marketId)` — 触发裁决（owner / OracleAdapter）
- `claimReward(marketId)` — 赢家领取奖励
- `setDefaultFee(feeBps)` — 设置全局默认手续费
- `setMarketFee(marketId, feeBps)` — 覆盖单个市场手续费
- `setFeeCollector(address)` — 设置手续费接收地址

### AMM 定价模型

采用恒定乘积做市，YES 和 NO 池互为对手盘：

- YES 价格 = outcomeYes / (outcomeYes + outcomeNo)
- NO 价格 = 1 - YES 价格
- 用户下注时，代币进入对应池，价格实时更新
- 裁决后赢家按份额比例瓜分输家池（扣除手续费）

### OracleAdapter

抽象层统一裁决接口：

- 场景 A (币价类): 通过 Chainlink Data Feeds 读取链上价格，与 threshold 比较
- 场景 B (自定义事件): 通过 Chainlink Automation 调用 API，将结果 push 上链
- 预留多源聚合接口

## 前端设计

### 页面路由

- `/` — 市场列表（进行中/已结束/待领奖）
- `/market/:id` — 市场详情 + 下注面板 + 实时赔率
- `/create` — 创建市场（仅 admin）
- `/portfolio` — 用户持仓 + 待领奖记录

### 关键交互

- 钱包连接: RainbowKit
- 代币授权 + 下注: 支持两步或通过 Permit 单步
- 实时价格: 下注后本地状态更新，或监听合约事件
- 领奖: 批量领取

## 手续费

- 全局默认: 200 bps (2%)
- 每个市场可独立覆盖
- 费用收入流向 feeCollector（初期项目方 → 后期 DAO Treasury）
- 可升级设计使修改手续费逻辑不需迁移市场

## 升级与治理演进

```
Phase 1 (MVP)           Phase 2                Phase 3
单管理员                Ownable → Timelock     Governor DAO
CornToken 无治理        + ERC20Votes           DAO 投票
Chainlink 裁决          + World ID 集成        社区裁决争议
```

- 合约使用 UUPS 代理，所有者可升级逻辑
- 存储布局预留 `__gap` 槽
- Phase 2 可直接将 owner 转移给 TimelockController

## 开发计划

1. Foundry 项目初始化 + OpenZeppelin 依赖
2. CornToken 合约 + 测试
3. PredictionMarket 合约（核心逻辑） + 测试
4. OracleAdapter + Chainlink 集成 + Fork 测试
5. 前端框架搭建 + 合约 ABI 集成
6. 合约部署到 World Chain 测试网
7. 前端对接测试网
8. 集成测试 + 安全审计
