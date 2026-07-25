# 治理前端页面 + 部署脚本设计

## 概述

实现 Phase 2/3 治理的前端交互界面（Delegate + Governance 页面）和 Foundry 部署脚本（DeployPhase2 + DeployPhase3）。

## Task 6 — 前端治理页面

### 新增文件

| 文件 | 说明 |
|------|------|
| `frontend/src/hooks/useGovernance.ts` | 治理相关 hooks：提案列表、提案状态、投票 |
| `frontend/src/pages/Delegate.tsx` | 包装/委托页 |
| `frontend/src/pages/Governance.tsx` | 提案列表 + 投票页 |

### 修改文件

| 文件 | 改动 |
|------|------|
| `frontend/src/contracts/abi.ts` | 追加 GovCrownToken + TokenHouse 的 human-readable ABI 和合约地址 |
| `frontend/src/App.tsx` | 添加 Governance / Delegate 导航按钮 + 路由状态 |

### 技术方案

- 沿用现有手动路由（`useState` 控制页面切换）
- 沿用 wagmi `useReadContract` / `useWriteContract` 读写合约
- 提案列表通过 viem `usePublicClient().getLogs()` 拉取 `ProposalCreated` 事件
- 无需后端、无需 The Graph、无需 Tally

### Delegate 页面（`/delegate`）

- 显示用户 CORN 余额、govCORN 余额、投票权重（`getVotes`）
- 存入流程：输入金额 → approve CORN → 调 `depositFor`
- 取出流程：输入金额 → 调 `withdrawTo`
- 委托流程：显示当前受托人 → 输入地址 → 调 `delegate`
- 支持委托给自己或他人

### Governance 页面（`/governance`）

- 进入页面自动拉取 `ProposalCreated` 事件日志
- 列表展示：提案 ID、描述摘要、状态、截止区块
- 点击展开详情：赞成/反对/弃权票数、提议人、快照区块、投票截止区块
- 投票按钮（For / Against / Abstain）
- 仅在 Active 状态且有投票权时显示投票按钮
- 状态自动映射：Pending → 待投票, Active → 进行中, Succeeded → 已通过, Queued → 已排队, Executed → 已执行, Defeated → 已否决, Canceled → 已取消, Expired → 已过期

### 不做

- 不在前端实现创建提案（需构造 calldata，可通过 Tally 或区块浏览器）
- 不在本 task 实现 HumanHouse 争议 UI（随 T8 一起做）

## Task 7 — 部署脚本

### 新增文件

| 文件 | 说明 |
|------|------|
| `script/DeployPhase2.s.sol` | Phase 2 部署：GovCrownToken + TimelockController + 所有权转移 |
| `script/DeployPhase3.s.sol` | Phase 3 部署：TokenHouse + HumanHouse + Timelock 角色配置 |

### DeployPhase2 流程

1. 部署 GovCrownToken（传入 CORN 地址）
2. 部署 TimelockController（minDelay=2天，proposers/executors 空，admin=部署者）
3. 设置 Timelock 角色：Safe 为 proposer，address(0) 为 executor
4. 撤销部署者 admin 角色
5. 转移 PredictionMarket 所有权给 Timelock
6. 转移 CornToken 所有权给 Timelock

### DeployPhase3 流程

1. 部署 TokenHouse（传入 GovCORN 地址 + Timelock 地址）
2. 部署 HumanHouse（传入 CORN 地址 + PredictionMarket 地址 + 争议押金）
3. Timelock 授予 TokenHouse PROPOSER_ROLE
4. Timelock 授予 HumanHouse PROPOSER_ROLE
5. 保留 Safe 作为 canceller
