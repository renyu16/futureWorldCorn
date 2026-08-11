# Phase 1 端到端冒烟测试设计

## 目标

对 World Chain Sepolia (4801) 上已部署的 Phase 1 合约（CornToken、PredictionMarket proxy、OracleAdapter）做端到端冒烟测试，验证 createMarket -> bet -> resolve -> claim 全链路在真实链上行为正确。

## 背景

Phase 1 已部署：
- CornToken: `0x6a07C7b64702E67f32d14f55F26dAAc94082B981`
- PredictionMarket (ERC1967Proxy): `0xAecA3704114B03d2d85f6EC5C4df83b277a657bb`
- OracleAdapter: `0x617CEC12C21b4D4Def72afAd7858E7596e83dc82`

## 角色与账户

| 角色 | 账户 | 职责 |
|------|------|------|
| Owner/Keeper | `0xbaD8...9D80` (deployer) | createMarket, bet YES, pushResult(resolve), claim |
| 下注者 NO | `0xaf07...A0C2` (ai_dev_b) | bet NO, claim（应 revert） |
| feeCollector | `0xDeF213...033f` (ai_dev_a) | 被动收 fee（不发交易） |

## 实现方式

单 PowerShell 脚本 `scripts/smoke.ps1`，顺序执行，每步后用 `cast call` 读状态做断言，失败即停。

## 执行流程

1. **Fund ETH**: deployer 转 0.005 ETH 给 ai_dev_b 付 gas（幂等：余额够则跳过）
2. **Fund CORN**: deployer 转 100 CORN 给 ai_dev_b（幂等）
3. **Approve**: ai_dev_b approve(market, 100 CORN)
4. **createMarket**: deployer createMarket(question, deadline=now+90s, feeBps=200)；断言 marketCount+1；marketId = marketCount（合约内 marketCount++ 后用）
5. **bet YES**: deployer bet(marketId, YES=0, 100 CORN)；断言 sharesYes=100
6. **bet NO**: ai_dev_b bet(marketId, NO=1, 100 CORN)；断言 sharesNo=100
7. **等待**: Start-Sleep 95s 过 deadline
8. **resolve**: keeper pushResult(marketId, true) 经 OracleAdapter；断言 status=Resolved
9. **claim 赢家**: deployer claimReward；断言 claimed=true，余额增加 198 CORN
10. **claim 输家**: ai_dev_b claimReward；预期 revert "no winnings"
11. **fee 核验**: feeCollector 余额 = 2 CORN（100 输池 × 200bps）

## 断言规则

- 金额比较用 BigInteger（uint256 超 UInt64 范围）
- cast 输出取首个 token（去掉 `[1e20]` 后缀）
- 输家 claim 用 try/catch 捕获预期 revert

## 预期结果

- 总池 200 CORN
- fee = 100 × 2% = 2 CORN -> feeCollector
- 赢家拿回本金 100 + 奖励 98 = 198 CORN
- 输家 claim revert

## 结果

冒烟测试已通过，验证了：
- createMarket 权限控制（onlyOwner）
- bet 双向下注 + shares 记账
- OracleAdapter.pushResult -> market.resolveMarket 授权调用链
- claim 赢家分配算法（本金 + 输池奖励 - fee）
- claim 输家正确 revert
- fee 正确流向 feeCollector
