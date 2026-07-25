# 预测大师双院制治理设计文档

## 概述

本文档描述预测大师 (Prediction Master) 从 MVP (Phase 1) 向去中心化治理演进的 Phase 2 和 Phase 3 设计方案。采用双院制 (Bicameral Governance) 架构，平衡代币持有者经济权益与社区人类共识。

## 演进路线

```
Phase 1 (MVP - 当前)     Phase 2 (过渡)           Phase 3 (去中心化)
┌──────────────┐        ┌──────────────────┐     ┌──────────────────────┐
│ 单管理员      │───────▶│ 多签 + Timelock   │────▶│ 双院制治理           │
│ EOA owner    │        │ GovCORN 投票权     │     │ TokenHouse           │
│ no governance│        │ 无争议裁决(维持)    │     │  + HumanHouse        │
└──────────────┘        └──────────────────┘     └──────────────────────┘
```

## Phase 2 — 过渡治理

### 目标

1. 将管理权限从 EOA 转移给 TimelockController，增加安全延迟
2. 引入 GovCORN 包装代币，为 Phase 3 投票做准备

### 组件

#### 2.1 多签钱包 (Safe)

- 标准 Safe 3/5 多签
- 签名者：核心团队 5 人中的 3 人
- 角色：TimelockController 的初始 proposer

#### 2.2 TimelockController

- OpenZeppelin 标准 TimelockController
- `minDelay`: 2 天
- Proposer: Safe 多签地址
- Executor: `address(0)` (任何人可执行)
- Admin: Safe 多签地址

#### 2.3 GovCrownToken (GovCORN)

- 新部署合约，继承 OpenZeppelin:
  - `ERC20Votes` — 支持委托和链上投票
  - `ERC20Permit` — 支持 gasless approve
  - `ERC20Wrapper` — 包装 CORN 1:1
- `name`: "Governance Crown Token", `symbol`: "govCORN"
- 功能:
  - `depositFor(address account, uint256 amount)` — 存入 CORN，铸造 govCORN
  - `withdrawTo(address account, uint256 amount)` — 销毁 govCORN，取回 CORN
  - `delegate(address delegatee)` — 委托投票权 (OZ ERC20Votes 标准)
  - `getVotes(address account)` — 查询投票权重
- 不设 owner，完全去中心化

#### 2.4 所有权转移

1. 部署 Safe 多签
2. 部署 TimelockController (proposer=Safe, executor=anyone)
3. 将 PredictionMarket.owner 转移给 TimelockController
4. 将 CornToken.owner 转移给 TimelockController

### Phase 2 管理流程

```
Safe 多签提案 ──▶ Timelock (2天排队) ──▶ 执行操作
  ↓                                              ↓
  setDefaultFee, setFeeCollector,              setResolver,
  合约升级, lockMint                            resolveMarket
```

### Phase 2 不做

- 不改变市场创建权限 (维持 onlyOwner)
- 不引入争议裁决机制
- 不做 World ID 集成

## Phase 3 — 双院制治理

### 架构

```
                    ┌──────────────────────────────┐
                    │      TimelockController       │
                    │   (minDelay: 3 天)             │
                    └──────────┬───────────────────┘
                               │
            ┌──────────────────┼──────────────────┐
            ▼                  ▼                   ▼
   ┌────────────────┐  ┌──────────────┐  ┌──────────────┐
   │   经济院        │  │   人类院      │  │   重叠区域    │
   │ (Token House)   │  │ (Human House) │  │              │
   │                │  │              │  │ 治理规则修改   │
   │  govCORN 投票   │  │ World ID 投票  │  │ 双院同时通过   │
   │  1 govCORN=1 票  │  │ 1 人 = 1 票   │  │              │
   ├────────────────┤  ├──────────────┤  └──────────────┘
   │ • 费率修改      │  │ • 市场争议    │
   │ • 金库支出      │  │ • 预言机结果   │
   │ • 合约升级      │  │   质疑推翻    │
   │ • 上架费设置    │  │ • 市场下架    │
   │ • feeCollector  │  │              │
   └────────────────┘  └──────────────┘
```

### 3.1 TokenHouse (经济院)

- OpenZeppelin `Governor` 标准实现
- 投票代币: GovCORN (ERC20Votes)
- 提案门槛: 总供应量的 1%
- 投票法定人数: 总供应量的 4%
- 投票周期: 3 天
- 执行延迟: 通过 Timelock 额外 3 天
- 决策范围:
  - `setDefaultFee()`
  - `setFeeCollector()`
  - `setMarketFee()`
  - 合约逻辑升级 (`_authorizeUpgrade`)
  - 金库支出 (如有)
  - `setListingFee()` (未来)

### 3.2 HumanHouse (人类院)

新合约 `HumanHouse.sol`:

```solidity
interface IHumanHouse {
    /// 发起争议投票
    function raiseDispute(
        uint256 marketId,
        DisputeType disputeType,  // OracleResult | MarketContent
        string calldata reason,
        uint256 root,
        uint256 nullifierHash,
        uint256[8] calldata proof
    ) external payable;

    /// 投票 (World ID 验证)
    function vote(
        uint256 disputeId,
        bool support,
        uint256 root,
        uint256 nullifierHash,
        uint256[8] calldata proof
    ) external;

    /// 执行争议结果
    function executeDispute(uint256 disputeId) external;
}
```

关键参数:
- 争议押金: 1000 CORN (可调整)
- 投票周期: 5 天
- 通过门槛: 参与投票的 World ID 用户 > 50% 同意
- 每个用户每争议只能投一票 (通过 nullifierHash 防重复)

执行效果:
- 预言机结果质疑通过: 调用 `resolveMarket(marketId, oppositeResult)`
- 市场内容投诉通过: 将市场标记为隐藏/下架

### 3.3 双院重叠区域

某些重大变更需要双院同时通过:
- 修改 TokenHouse 或 HumanHouse 参数 (提案门槛、投票周期等)
- 修改双院制本身的设计 (如取消某一院)
- 升级 HumanHouse 合约逻辑

流程: TokenHouse 提案 → 通过 → HumanHouse 确认投票 → 执行

### 3.4 TimelockController 升级

Phase 3 中 TimelockController 更新:
- `minDelay`: 2→3 天
- Proposers: TokenHouse (Governor) 地址 + HumanHouse 地址
- 保留 Safe 多签作为 `canceller` (紧急情况下取消恶意提案)

## 合约清单

| 合约 | Phase | 说明 |
|------|-------|------|
| `GovCrownToken.sol` | P2 | ERC20Votes 包装代币 |
| `HumanHouse.sol` | P3 | World ID 争议裁决 |
| `TokenHouse.sol` | P3 | OZ Governor (或直接部署 OZ 标准) |
| `PredictionMarket.sol` | P1→P2 | UUPS 升级，owner 转移给 Timelock |

## 不变更的合约

- `CornToken.sol` — 保持简单 ERC20，通过 GovCORN 获得治理能力
- `OracleAdapter.sol` — 维持现有功能

## 前端影响

| 页面 | Phase 2 | Phase 3 |
|------|---------|---------|
| 市场列表 | 无变化 | 争议中标记 |
| 市场详情 | 无变化 | 发起争议按钮 |
| Portfolio | 增加 GovCORN 存款/取款 | 投票记录 |
| 治理(新) | 委托页面 | 提案列表 + 投票 |

## 安全考虑

1. Timelock 延迟保护: 所有管理操作有 2-3 天窗口供用户退出
2. 双院制防共谋: 经济权和人类权分离，避免巨鲸同时控制
3. World ID 防女巫: 一人一票需 ZKP 验证
4. 押金经济安全: 恶意发起争议损失押金
5. 渐进式移交: Phase 2 多签保留取消权 (canceller) 作为安全刹车
