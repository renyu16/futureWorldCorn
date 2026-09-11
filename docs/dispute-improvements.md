# HumanHouse 争议机制改进方案

## 当前已知问题

| 问题 | 现状 | 风险等级 |
|------|------|----------|
| 抵押金额固定 | `disputeDeposit` 全市场统一，owner 可调 | P2 |
| 投票权重相同 | 1票=1票，大户小户权重一样 | P3 |
| 翻转后已领取奖励无法追回 | 已领走的 CORN 不退回，存在抢跑激励 | P1 |
| 投票期固定 5 天 | 所有争议统一 5 天 | P4 |
| World ID 尚未真实集成 | mock 零值证明，可重复刷票 | P0 |

---

## 改进方案

### P0：World ID 真实集成

**问题**：当前 `vote()` 传 mock 零值证明，任何人都能重复投票，去中心化程度存疑。

**方案**：前端集成 `@worldcoin/idkit` 生成真实证明。

- 前端调用 `@worldcoin/idkit` 的 `verify()` 生成真实 proof/root/nullifierHash
- 合约已实现 `verifyProof()` 逻辑（`HumanHouse.sol:105-112`），只是当前 mock
- 需要配置真实 `WORLD_ID_APP_ID` 和 `WORLD_ID_ROUTER_ADDRESS`
- 依赖：`npm install @worldcoin/idkit`（当前 `package.json` 无此依赖）
- Router 地址：部署脚本已有 `WORLD_ID_ROUTER_ADDRESS` 环境变量（`.env.example:21`）

**工作量**：前端 1-2 天 + 合约已就绪

---

### P1：翻转后追回机制

**问题**：`disputeResolve` 只翻转结果，已通过 `claimReward` 领走的 CORN 不退回。先领的人无风险，后领的人受损，存在抢跑激励。

**方案**：冻结期 + 快照机制。

```
raiseDispute
  → 立即冻结所有未 claim 的 claimReward（标记 pending）
  → 记录快照：每市场每用户已领取金额

5天投票期

executeDispute（争议通过，翻转结果）
  → 翻转结果后，按新结果重新计算所有 claim
  → 已领取的：差额从用户余额扣除（或标记债务）
  → 未领取的：按新结果结算
```

**需要改动**：
- PredictionMarket 新增 `frozen` 映射（`mapping(uint256 => bool)`）
- 新增 `claimReward()` 检查冻结状态，冻结期间 revert
- HumanHouse `executeDispute()` 调用 `unfreezeAndRecalculate()`
- 复杂度较高，但彻底解决抢跑问题

**工作量**：合约 2-3 天 + 前端适配

---

### P2：按市场资金动态抵押

**问题**：`disputeDeposit` 全市场统一，大市场抵押太小容易被滥用，小市场抵押太高没有门槛意义。

**方案**：按市场总下注额动态计算。

```
disputeDeposit = max(baseDeposit, marketPool * disputeRatio / 10000)
```

- `baseDeposit`（owner 可调）：最低抵押，防止零抵押垃圾争议
- `marketPool`：该市场总下注额（`outcomeYes + outcomeNo`）
- `disputeRatio`：比例系数，如 500（5%），owner 可调
- 所有参数 owner 可通过 `setDisputeDeposit()` 等函数调整

**需要改动**：
- HumanHouse 新增 `disputeRatio` 参数
- `raiseDispute()` 计算动态抵押（需 eth_call 读取 PredictionMarket 的 market 数据）
- 或 PredictionMarket 新增 `getDisputeDeposit(marketId)` view 函数供 HumanHouse 调用

**工作量**：合约 1 天

---

### P3：投票权重加权

**问题**：1票=1票，持币大户没有动力参与投票，小户可能被贿赂收买。

**方案**：按持仓加权投票（平方根函数）。

```
voteWeight = sqrt(userCORNBalance + userGovCORNBalance)
```

- 用平方根函数（Vitalik 推荐的平方根投票，防巨鲸垄断）
- `votesFor` / `votesAgainst` 类型从 `uint256` 改为支持小数（如 `uint256` 乘以 1e18）
- 需要 World ID 验证（防同一人多地址刷票）—— 依赖 P0

**需要改动**：
- HumanHouse `vote()` 读取 CORN/govCORN 余额
- `votesFor`/`votesAgainst` 计算改为加权
- 前端显示投票权重

**工作量**：合约 1 天 + 前端适配

---

### P4：投票期分级

**问题**：`votingPeriod = 5 days`，所有争议统一，简单事实争议拖太久，复杂争议时间不够。

**方案**：按争议类型设置不同投票期。

```
OracleResult（技术争议） → 3 天（快决断）
MarketContent（规则争议） → 7 天（充分讨论）
```

或更激进：大额争议延长投票期（如 marketPool > 10万 CORN → 7天），小额争议缩短（<1000 CORN → 3天）。

**需要改动**：
- HumanHouse 新增 `oracleVotingPeriod` 和 `contentVotingPeriod` 参数
- `raiseDispute()` 根据类型设置不同 deadline

**工作量**：合约 0.5 天

---

## 实施优先级

| 阶段 | 内容 | 工作量 | 依赖 |
|------|------|--------|------|
| Phase 1 | P0：World ID 真实集成 | 1-2 天 | @worldcoin/idkit |
| Phase 1 | P1：翻转后追回机制 | 2-3 天 | — |
| Phase 2 | P2：动态抵押 | 1 天 | — |
| Phase 2 | P4：投票期分级 | 0.5 天 | — |
| Phase 3 | P3：投票权重加权 | 1 天 | P0（World ID） |

**Phase 1 是上链前必须解决的**（P0 保证投票去中心化，P1 保证资金安全）。
**Phase 2-3 可以迭代**，不影响核心功能。
