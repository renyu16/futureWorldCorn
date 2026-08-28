# 实现计划：Prediction Master 本地测试体系建设（cr-173908）

## 元信息
- 需求ID：173908 ｜ 关联脑暴：docs/brainstorm/cr-173908-local-test-20260706.md
- 决策依据：D1=Mock依赖注入 ｜ D2=仅合约侧 ｜ D3=暂缓接口改造
- 目标：在不修改 `HumanHouse` 源码接口的前提下，建立零外部 RPC 的合约本地测试体系；覆盖现有业务逻辑，并以追踪性测试暴露实现缺口。

## 源码事实核对（Plan 阶段重新核对，修正脑暴推断偏差）
脑暴阶段基于测试文件推断，Plan 阶段核对 `src/HumanHouse.sol` 真实实现，修正如下：
- **防重复机制**：当前为**地址级** `hasVoted[disputeId][msg.sender]`，**非** World ID `nullifierHash` 级（World ID 未集成，`_verifyWorldId()` 内部返回 `true`）。
- **押金形式**：`raiseDispute` 通过 `cornToken.safeTransferFrom(msg.sender, ...)` 扣 **ERC20 CORN**（`disputeDeposit` 状态变量），**非** `msg.value` payable。
- **通过判定**：`votesFor > votesAgainst`（简单多数），非 50% 参与率。
- **`executeDispute` 当前仅处理押金**：`Approved`→退押金给 initiator；`Rejected`→押金留合约（owner 经 `withdrawFees()` 提取）。**未**调用 `resolveMarket` 或标记市场隐藏。

## 关键发现（务必阅知）
设计文档（bicameral-governance-design.md §3.2）承诺 `executeDispute` 在 OracleResult 通过时调用 `resolveMarket(marketId, opposite)`、MarketContent 通过时标记市场下架；**当前 `src/HumanHouse.sol` 未实现该副作用**，仅有押金逻辑。此缺口超出本期"测试建设"范围，本计划在任务 5 以追踪性测试暴露，不实现（遵循 D3 暂缓改造）。

## 任务列表

### 任务 1：建立本地测试基线
- 文件：test/*（只读验证）
- 描述：运行 `forge test -vvv`，确认当前 7 个测试文件全绿，记录测试函数总数作为回归基线。
- 验证：`forge test` 全通过，记录基线测试数。
- 依赖：无
- 时间：5 分钟

### 任务 2：raiseDispute 押金与权限测试
- 文件：test/HumanHouse.t.sol
- 描述：新增 `test_RaiseDisputeTransfersDeposit`（raiseDispute 后合约 CORN 余额 +disputeDeposit、initiator 余额 -disputeDeposit）、`test_RaiseDisputeRequiresApproval`（未 approve 回滚）、`test_DisputeCounterIncrements`、`test_RaiseDisputeEmitsEvent`。
- 验证：余额变动精确匹配 `disputeDeposit`；未授权转账回滚。
- 依赖：任务1
- 时间：5 分钟

### 任务 3：vote 防重复与投票期测试
- 文件：test/HumanHouse.t.sol
- 描述：新增 `test_VoteRecords`（votesFor=1）、`test_DoubleVoteReverts`（同地址二次 vote 回滚 "already voted"）、`test_VoteAfterDeadlineReverts`（warp 过 deadline 回滚 "voting ended"）、`test_VoteWhenPausedReverts`（pause 后）。
- 验证：地址级防重复；时间窗约束生效。
- 依赖：任务1
- 时间：5 分钟

### 任务 4：executeDispute 状态机与押金经济测试
- 文件：test/HumanHouse.t.sol
- 描述：新增 `test_ExecuteApprovedRefundsDeposit`（votesFor>votesAgainst 后 state=Approved 且 initiator 收回 deposit）、`test_ExecuteRejectedForfeitsDeposit`（votesFor<=votesAgainst 后 state=Rejected，deposit 留合约）、`test_WithdrawFeesAfterReject`（Rejected 后 owner.withdrawFees() 提取 forfeited 部分）、`test_ExecuteBeforeDeadlineReverts`、`test_ExecuteTwiceReverts`（state 非 Active 后回滚 "not active"）。
- 验证：押金经济与状态机正确；withdrawFees 仅提 forfeited。
- 依赖：任务2、3
- 时间：5 分钟

### 任务 5：executeDispute 裁决副作用缺口追踪（不实现）
- 文件：test/HumanHouse.t.sol
- 描述：以注释 + 预期失败（或 `@skip`）测试记录设计承诺但未实现的副作用：OracleResult 通过应调用 `pm.resolveMarket(marketId, opposite)`；MarketContent 通过应标记市场隐藏。当前断言会失败，标记为已知缺口 GAP-1，作为回归守卫。
- 验证：测试清晰标注 GAP-1，CI 不阻塞（skip 或独立标记）。
- 依赖：任务4
- 时间：4 分钟

### 任务 6：GovCrownToken 委托与投票权测试
- 文件：test/GovCrownToken.t.sol
- 描述：新增 `test_DepositForMints1to1`（depositFor 铸 govCORN 1:1）、`test_WithdrawToBurns`（withdrawTo 销毁取回 CORN）、`test_DelegateUpdatesVotes`（delegate 后 getVotes(delegatee) 增加）、`test_GetVotesBeforeDelegateZero`、`test_WrapIntegrity`。
- 验证：包装比例精确 1:1；委托后投票权重正确。
- 依赖：任务1
- 时间：5 分钟

### 任务 7：治理集成骨架（GovCORN 委托链路）
- 文件：test/integration/GovernanceIntegration.t.sol（新建）
- 描述：部署 GovCrownToken + PredictionMarket，验证 alice depositFor 后 delegate 给 bob，bob.getVotes 反映 alice 余额；构造"提案阈值快照"helper，为未来 TokenHouse（OZ Governor）真实提案流预留 harness；注释标注 TokenHouse 实现后填充。
- 验证：委托后 getVotes 正确，快照可用于阈值判断。
- 依赖：任务6
- 时间：5 分钟

### 任务 8：部署脚本 anvil dry-run
- 文件：test/DeployDryRun.t.sol（新建）
- 描述：在测试内复刻 Deploy.s.sol 初始化顺序（Safe 多签 → TimelockController → PredictionMarket.owner / CornToken.owner 转移给 Timelock），断言部署后 owner == Timelock。
- 验证：部署后 `PredictionMarket.owner() == timelock` 且 `CornToken.owner() == timelock`。
- 依赖：任务1
- 时间：5 分钟

### 任务 9：本地测试说明（Makefile/README）
- 文件：Makefile
- 描述：确认 `make test`（`forge test -vvv`）一条命令全量可跑；补充"无需外部 RPC"声明与新增测试说明。
- 验证：文档清晰，`make test` 可运行。
- 依赖：任务2–8
- 时间：3 分钟

### 任务 10：全量回归与覆盖率
- 文件：test/*
- 描述：运行 `forge test -vvv` 与 `forge coverage`，确认全绿且覆盖率相对基线无回归（缺口追踪测试除外）。
- 验证：全部通过；覆盖率记录。
- 依赖：任务2–9
- 时间：5 分钟

## 执行顺序与依赖图
```
任务1 → 任务2 ─┐
任务1 → 任务3 ─┴→ 任务4 → 任务5
任务1 → 任务6 → 任务7
任务1 → 任务8
任务2–8 → 任务9 → 任务10
```
可并行批次：{2,3,6,8} → {4,7} → {5,9} → {10}

## 退出标准
- `forge test -vvv` 全绿（缺口追踪测试以 skip/标记隔离，不阻塞）。
- 新增覆盖：HumanHouse 押金/防重复/状态机、GovCrownToken 委托、治理骨架、部署 dry-run。
- 文档更新（Makefile）。

## 风险与开放问题
- **R1（关键）**：`executeDispute` 裁决副作用缺失（GAP-1），影响 Phase 3 人类院可用性；建议单独立项实现，不在本期。
- **R2**：`withdrawFees` 语义依赖 `_totalActiveDeposits` 精确逻辑，任务4 验证需按实现断言。
- **Q1**：GAP-1 是否需在 execute 阶段顺带实现（超出 D2/D3 范围）？
- **Q2**：缺口追踪测试用 `@skip` 还是独立 CI 标记？

---

*下一步：用户 sign-off 后进入 Execute 阶段（proflow execute），按任务列表落地测试代码。*
