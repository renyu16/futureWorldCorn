# 争议处理完整方案

## 设计决策

- **放弃追回已领取奖励**：Polymarket / Augur / Kalshi / Kleros 均不追回，行业共识
- **前置冻结窗口**：结算后 24h 冻结 Claim，争议在领取前解决
- **消灭争议优先**：市场创建时强制写清结算规则，从源头消灭争议
- **分级处理**：低争议快速通过，高争议升级仲裁

---

## 当前合约漏洞

| 漏洞 | 影响 | 修复 |
|------|------|------|
| `disputeResolve` 无防重复调用 | resolver 可无限次翻转 result | 加 disputeCount/disputeLocked |
| Market 无数据源字段 | 争议时无法证明对错 | Market 结构体加 resolutionSource |
| `disputeResolve` 要求 Resolved 状态 | 设计合理（需先结算再争议） | 保持 |

---

## 分层方案

### 层级一：消灭争议（Kalshi 模式）

**原理**：有明确数据源的市场，争议率趋零。

**实现**：Market 结构体新增字段

```solidity
struct Market {
    string question;
    uint128 outcomeYes;
    uint128 outcomeNo;
    uint40 deadline;
    MarketStatus status;
    bool result;
    uint16 feeBps;
    string resolutionSource;  // 新增：结算数据源
    string resolutionRule;    // 新增：首版/官方/社区共识
    string edgeCase;          // 新增：特殊情况处理
}
```

- `resolutionSource`：数据来源（"Chainlink Feed 0x..." / "BLS CPI" / "CoinGecko" / "社区共识"）
- `resolutionRule`：结算规则（"首版数据为准" / "官方公告为准" / "社区投票"）
- `edgeCase`：边缘情况处理（"数据延迟→按延迟版本" / "50-50各返50%"）

**前端改动**：创建市场页面增加三个字段（可选，不填则为社区共识市场）。

---

### 层级二：冻结窗口（Polymarket 模式）

**原理**：结算后 24h 冻结，无人争议则终局，有人争议则进入投票。

```
市场结算（resolveMarket）
  → claimFrozen[marketId] = true
  → disputeDeadline[marketId] = now + 24h

挑战期内：
  无人 raiseDispute → 窗口结束 → claimFrozen = false → 正常 claim
  有人 raiseDispute → 进入投票 → 翻转或否决 → 解冻

已领取的：不追回（行业共识）
```

**实现**：

```solidity
// PredictionMarket 新增
mapping(uint256 => bool) public claimFrozen;
mapping(uint256 => uint256) public disputeDeadline;
uint256 public constant DISPUTE_WINDOW = 24 hours;

// resolveMarket 改动：结算时自动冻结
function resolveMarket(uint256 marketId, bool result) external {
    // ... 原有逻辑
    m.status = MarketStatus.Resolved;
    m.result = result;
    claimFrozen[marketId] = true;
    disputeDeadline[marketId] = block.timestamp + DISPUTE_WINDOW;
}

// claimReward 改动：检查冻结
function claimReward(uint256 marketId) external nonReentrant {
    require(!claimFrozen[marketId], "claims frozen");
    // ... 原有逻辑
}

// HumanHouse 解冻
function unfreezeMarket(uint256 marketId) external {
    PredictionMarket(predictionMarket).unfreezeClaims(marketId);
}
```

**HumanHouse 改动**：
- `executeDispute` 通过后调用 `unfreezeClaims(marketId)`
- 无争议自动解冻需链下 bot 或预言机自动触发

---

### 层级三：动态抵押（防垃圾争议）

**原理**：按市场资金规模动态调整抵押，大市场高门槛，小市场低门槛。

```
disputeDeposit = max(baseDeposit, marketPool * disputeRatio / 10000)
```

- `baseDeposit`：最低抵押（owner 可调，如 100 CORN）
- `marketPool`：市场总下注额（`outcomeYes + outcomeNo`）
- `disputeRatio`：比例系数（如 500 = 5%，owner 可调）

**实现**：

```solidity
// HumanHouse 新增
uint256 public baseDeposit;
uint256 public disputeRatio = 500; // 5%

function getDisputeDeposit(uint256 marketId) public view returns (uint256) {
    (,uint128 outcomeYes, uint128 outcomeNo,,) = IPredictionMarket(predictionMarket).markets(marketId);
    uint256 pool = uint256(outcomeYes) + uint256(outcomeNo);
    uint256 dynamic = pool * disputeRatio / 10000;
    return dynamic > baseDeposit ? dynamic : baseDeposit;
}

function raiseDispute(...) external {
    uint256 deposit = getDisputeDeposit(marketId);
    cornToken.safeTransferFrom(msg.sender, address(this), deposit);
    // ...
}
```

---

### 层级四：World ID 真实集成

**原理**：抗 Sybil，保证一人一票。

**实现**：
- 前端调用 `@worldcoin/idkit` 的 `verify()` 生成 proof
- 合约已有 `verifyProof()` 逻辑（`HumanHouse.sol:105-112`）
- 配置真实 `WORLD_ID_APP_ID` 和 `WORLD_ID_ROUTER_ADDRESS`

**依赖**：`npm install @worldcoin/idkit`（前端）

---

### 层级五：投票权重加权（可选迭代）

**原理**：持仓越大，投票权重越大，但用平方根函数防巨鲸。

```
voteWeight = sqrt(userCORNBalance + userGovCORNBalance)
```

**实现**：
- `votesFor`/`votesAgainst` 改为 `uint256`（乘以 1e18 表示精度）
- `vote()` 读取 CORN/govCORN 余额
- 需 World ID 验证（依赖层级四）

---

### 层级六：Kleros 仲裁嵌入（可选高价值市场）

**原理**：重大争议升级到去中心化陪审团。

**升级路径**：
```
一次投票票数接近（如差距 < 10%）→ 升级到 Kleros
→ 创建 Kleros Case（提交市场规则 + 双方证据）
→ 随机抽选陪审员（质押 + 奖励）
→ 陪审员投票裁决（最终，不可逆）
```

**实现**：调用 Kleros `createCase` 合约（独立协议，无需自建）

---

## 完整流程

```
创建市场
  ├─ question + deadline + feeBps（已有）
  ├─ resolutionSource（新增：结算数据源）
  ├─ resolutionRule（新增：首版/官方/社区共识）
  └─ edgeCase（新增：特殊情况）
  │
  ▼
下注阶段
  │
  ▼
deadline 到 → resolveMarket()
  │
  ▼
冻结窗口（24h）
  │
  ├─ 无争议 → 窗口结束 → 冻结解除 → 正常 claim
  │
  └─ 有争议 → raiseDispute()（交动态抵押）
      │
      ▼
    World ID 一人一票投票（5天）
      │
      ├─ 通过 → disputeResolve（翻转）→ 解冻 → 按新结果 claim
      │
      ├─ 否决 → 解冻 → 按原结果 claim
      │
      └─ 票数接近 / 高争议金额 → 升级到 Kleros 仲裁（可选）
      │
      └─ 争议次数达上限 → disputeLocked，结果终局
```

---

## 实施优先级

| 阶段 | 内容 | 工作量 | 依赖 |
|------|------|--------|------|
| Phase 1 | 修复 disputeResolve 重复调用漏洞 | 0.5 天 | — |
| Phase 1 | Market 结构体加数据源字段 | 1 天 | — |
| Phase 1 | 冻结窗口（claimFrozen + disputeDeadline） | 1 天 | — |
| Phase 2 | 动态抵押 | 1 天 | — |
| Phase 2 | 投票期分级（OracleResult 3天 / MarketContent 7天） | 0.5 天 | — |
| Phase 3 | World ID 真实集成 | 1-2 天 | @worldcoin/idkit |
| Phase 4 | 投票权重加权 | 1 天 | Phase 3 |
| Phase 5 | Kleros 仲裁嵌入 | 2-3 天 | — |

**Phase 1（2.5天）是合约重构时必须做的**：修复漏洞 + 结算规则前置 + 冻结窗口。
**Phase 2-5 可以迭代**，不影响核心功能。
