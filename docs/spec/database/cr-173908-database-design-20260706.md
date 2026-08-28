# 链上状态/存储设计：Prediction Master 本地测试体系（cr-173908）

> 说明：本需求为合约侧测试体系建设，**无外部/链下关系型数据库**。所有被测状态均位于 EVM 链上存储。本章记录测试中**构造、断言所依赖的链上状态布局**，作为测试 fixture 与断言的权威来源。非传统 RDBMS 设计文档。

- 需求ID：173908
- 关联：PRD `cr-173908-prd-20260706.md`、架构 `cr-173908-architecture-20260706.md`
- 日期：2026-07-06

---

## 1. 被测状态总览

| 合约 | 关键状态变量 | 测试用途 |
|------|-------------|---------|
| `HumanHouse` | `disputes[marketId]`（status/deadline/votesFor/votesAgainst/deposit） | 争议状态机断言 |
| `HumanHouse` | `hasVoted[marketId][voter]` | 防重复投票断言 |
| `HumanHouse` | `disputeDeposit`、`votingPeriod`（owner 参数） | 参数设置权限断言 |
| `GovCrownToken` | `balanceOf` / `totalSupply` / `_delegatees` | 1:1 包装与委托投票权断言 |
| `CornToken` | `balanceOf` / `totalSupply`（固定 10 亿） | 押金冻结/释放断言 |
| `PredictionMarket` | `markets[marketId]`（状态/份额/手续费） | 回归基线 |
| `Timelock` | `admin` / `proposers` / `executors` | 部署不变量断言 |

## 2. 测试 Setup 状态快照（fixture）

集成测试 `GovernanceIntegration` 构造的链上初始状态：

```
alice: 持有 CORN 1000e18
  └─ depositFor(bob, 1000e18)  → 锁定 CORN，mint govCORN 1000e18 给 bob
bob.delegate(bob)              → bob.getVotes() == 1000e18
提案阈值快照 = govCORN.totalSupply() / 100   (1%)
```

部署 dry-run `DeployDryRun` 构造的链上初始状态：

```
Deploy.s.sol:
  CornToken deploy (owner = deployer)
  GovCrownToken deploy (CORN addr)
  PredictionMarket deploy (UUPS, CORN addr)
  HumanHouse deploy (CORN addr, market addr)
TransferToTimelock.s.sol:
  market.transferOwnership(Timelock)
  token.transferOwnership(Timelock)
  Timelock 自管 admin
  Safe = proposer, Executor = address(0)
```

## 3. 断言依赖的状态转换

### HumanHouse 争议生命周期
```
raiseDispute ──→ ACTIVE (冻结 deposit, 记录 deadline=now+votingPeriod)
   │
   ├─ vote(+) ──→ votesFor++
   ├─ vote(-) ──→ votesAgainst++
   │
   └─ executeDispute (now ≥ deadline)
         ├─ votesFor > votesAgainst → REJECTED (deposit 没收, owner 可 withdrawFees)
         └─ 否则                     → UPHELD   (deposit 退还)
```

断言点：
- `raiseDispute` 后：`balanceOf(caller)` 减少 `disputeDeposit`。
- `vote` 后：`hasVoted[marketId][voter] == true`（防重复）。
- `executeDispute` 后（REJECTED）：`withdrawFees()` 使 owner 余额增加没收额。
- 二次 `executeDispute`：`status != ACTIVE` → 回滚 `"not active"`。

### GovCrownToken 委托
```
depositFor(recipient, amt) → 锁定 CORN, mint govCORN(amt) to recipient
recipient.delegate(delegatee) → getVotes(delegatee) += amt
```
断言点：委托前 `getVotes == 0`；委托后 `getVotes(delegatee) == amt`；`totalSupply == 锁定 CORN 总量`。

## 4. 存储布局注意事项

- `GovCrownToken` 为 `ERC20Votes`，`getVotes` 依赖 checkpoint 机制；测试中 `delegate` 后**同一区块**查询即可生效（无需 warp）。
- `HumanHouse.disputes` 为 `mapping(uint256 => Dispute)`，测试需显式选取未占用 `marketId` 避免与 `PredictionMarket` 既有市场冲突。
- 所有 CORN 交互以 `IERC20(CORN)` 接口调用，测试 fixture 中需先 `mint`/`approve` 给测试账户。

## 5. 与传统数据库的边界

- **无 off-chain DB**：不存在 SQL/NoSQL 表，所有状态在链上。
- **状态持久化**：由 EVM 存储保证，测试通过 `vm.warp/prank` 控制而非数据库事务。
- **测试隔离**：每个 `test_*` 函数运行于独立 anvil fork 状态（Foundry 默认），无需数据库级 rollback/truncate。

> 结论：本需求无需传统 database-design 文档；链上状态布局（本章）即测试的"数据模型"。若未来引入 off-chain 索引（如 subgraph / 后端缓存），应单独立项，不在本期范围。
