# HumanHouse 争议机制改进方案

## 当前已知问题

| 问题 | 现状 | 风险等级 |
|------|------|----------|
| 抵押金额固定 | `disputeDeposit` 全市场统一，owner 可调 | P2 |
| 投票权重相同 | 1票=1票，大户小户权重一样 | P3 |
| 翻转结果无冻结期 | 结算后立即 claim，存在抢跑激励 | P1 |
| 投票期固定 5 天 | 所有争议统一 5 天 | P4 |
| World ID 尚未真实集成 | mock 零值证明，可重复刷票 | P0 |

## 设计决策：放弃追回已领取奖励

对标 Polymarket / Augur / Kalshi / Kleros 各平台，**没有任何平台在结算后追回已领取的奖励**，结果均不可逆。追回机制（债务账本、余额扣除）链上无法强制、复杂度高、会伤害正常用户，且 Polymarket 已用实践验证"系统按设计运行=不退款"。

**因此：不从用户钱包追回，改为在结算后设置冻结窗口，把争议前置到领取之前。**

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

### P1：Claim 冻结窗口（防抢跑）

**问题**：`disputeResolve` 只翻转结果，已通过 `claimReward` 领走的 CORN 不退回。先领的人无风险，后领的人受损，存在抢跑激励。

**行业共识**：Polymarket / Augur / Kalshi 均不追回已领取奖励，结果终局不可逆。追回机制（债务账本/扣余额）复杂度高、链上无法强制、还会伤害正常用户。**决策：放弃追回，改为前置冻结窗口。**

**方案**：结算后的挑战期内冻结 Claim，无争议则正常解冻。

```
市场结算（resolveMarket）
  → 进入挑战期（如 24h），claimFrozen[marketId] = true
  → 所有人无法 claimReward

挑战期内：

  无人 raiseDispute
    → 挑战期结束，claimFrozen = false
    → 用户正常 claim，结果终局

有人 raiseDispute
    → 进入 HumanHouse 投票（World ID 一人一票）
    → 投票通过 → 翻转结果 → 解冻 → 按新结果 claim
    → 投票否决 → 解冻 → 按原结果 claim

已领取的（历史结算时代的少数情况）：不追回
```

**需要改动**：
- PredictionMarket 新增 `claimFrozen` 映射（`mapping(uint256 => bool)`）
- `claimReward()` 检查冻结状态，冻结期间 revert
- `resolveMarket()` 结算时自动进入冻结期，计时器到期后自动解冻（或 HumanHouse 调用解冻）
- 可选：OracleAdapter 结算同样先冻结，留给争议窗口

**收益**：
- 彻底消除抢跑（争议期内领不走）
- 不惩罚正常用户（无债务、无扣款）
- 复杂度低（仅一个冻结开关 + 计时器）
- 符合主流平台行为（Polymarket 2h 挑战期即为此模式）

**权衡**：结算后用户要等冻结期才能领，增加 24h 延迟。Polymarket 同样有 2h 挑战期，用户已习惯。

**工作量**：合约 1-2 天 + 前端适配

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
