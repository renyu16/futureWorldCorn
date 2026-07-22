# HumanHouse 前端页面设计

日期: 2026-07-22

## 概述

为 HumanHouse 合约实现完整的前端争议管理页面，包含争议列表、发起争议、World ID 投票、执行争议四个功能。

## 新增文件

| 文件 | 用途 |
|---|---|
| `frontend/src/pages/HumanHouse.tsx` | 争议列表 + 发起争议 + 投票 + 执行 |
| `frontend/src/hooks/useHumanHouse.ts` | 合约读写 hook 封装 |

## 修改文件

| 文件 | 改动 |
|---|---|
| `frontend/src/App.tsx` | 添加 `humanhouse` 页面路由和导航按钮 |

## 页面功能

### 1. 争议列表（主视图）

- 用 `getLogs` 读 `DisputeCreated` 事件，聚合展示所有争议
- 每行显示：disputeId、marketId、类型（Oracle/Content）、状态（Active/Approved/Rejected）、reason、赞成/反对票数、截止时间
- 点击进入详情

### 2. 发起争议（raiseDispute）

- 输入 marketId，选择类型（0=OracleResult, 1=MarketContent），填写 reason
- 自动读取 `disputeDeposit()` 显示需要质押的 CORN 数量
- 需先 approve CORN → HumanHouse，再调 `raiseDispute`

### 3. 投票（vote + World ID）

- Active 状态的争议可投票（For/Against）
- Mock proof 模式：用固定 root/nullifierHash/proof[8] 调用 vote()
- UI 上显示"World ID 验证"占位区域，后续切换为真实 IDKit

### 4. 执行争议（executeDispute）

- 过了 deadline 的 Active 争议可执行
- 调用 `executeDispute(disputeId)`

## 数据流

```
DisputeCreated events → getLogs → disputes 列表
disputes(id) → 单个争议详情（状态/票数/deadline）
raiseDispute → approve + raiseDispute
vote → mock proof → vote()
executeDispute → executeDispute()
```

## UI 风格

- 沿用现有 inline styles，无 CSS 框架
- 卡片式布局：`border: '1px solid #ccc'`, `padding: 12`, `borderRadius: 6`
- 状态颜色：Active=#5bc0de, Approved=#5cb85c, Rejected=#d9534f
- 所有地址使用 `abi.ts` 中的占位符

## World ID 集成

- 当前使用 mock proof（固定值），vote() 调用会走合约 verifyProof 但会 revert（mock router 只在测试环境生效）
- 后续部署时安装 `@worldcoin/idkit`，替换为真实 ZKP 生成
