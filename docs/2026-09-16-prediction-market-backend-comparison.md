# 成熟预测市场后端技术栈对比

日期：2026-09-16
用途：为「是否改造 our project 后端」提供决策参考。结论先讲：**当前 Node 栈与主流单一开发者预测市场（Manifold）同级别，暂不改造**。

| 平台 | 类型 | 后端语言 | 撮合/核心机制 | 数据/索引层 | 结算与仲裁 | 对 our project 的参考点 |
|---|---|---|---|---|---|---|
| **Polymarket** | 去中心化（Polygon）+ 中心化体验 | **Go** 为主（核心交易）、Python/Java 按需、SDK 含 Python/TS | 链下 CLOB 撮合 + 链上结算（Gnosis CTF / UMA） | Postgres（事务）+ ClickHouse（分析/榜单）+ Redis + Kafka/Pulsar | UMA Optimistic Oracle（提案+押金+挑战期→DVM 投票） | "服务器代签广播结算"正是其 CLOB 运营商模型（精简版） |
| **Kalshi** | 中心化交易所（CFTC 监管） | **Go / Rust / C++**（撮合引擎）+ Python（数据） | 链下强一致 CLOB（无事件最终一致性） | Postgres + Redshift/Snowflake + Kafka + Dagster/dbt | 中心化 Markets Team 判定 + 规则条款（Source Agency）；无正式争议 | 生命周期状态机 + Request-to-Settle"按钮交互" |
| **Manifold** | Play-money（无链） | **全 TypeScript monorepo**（Next.js + Firebase Cloud Functions / GCP Docker 内部 API） | 服务器算 market 数学（CPMM） | 曾 Firestore → Supabase/Postgres（已迁移） | 市场创建者自己判定 + 管理员 | ⭐ 与 our project 技术栈几乎一致（TS 全栈 + 轻服务端） |
| **Azuro** | 去中心化（EVM，AMM 路线） | **Solidity 核心** + 中心化后端 API（Node）+ The Graph | 链上 vAMM + LiquidityTree 单池 | The Graph subgraph（历史/成交）+ WebSocket live feed + 中心化 bet 计算 API | Data Provider 判定 + AzuroDAO 兜底仲裁 | 我们不是 AMM；但其 Data Provider + DAO 仲裁 = owner 结算 + HumanHouse 仲裁 |
| **Omen(Gnosis)** | 去中心化（Gnosis Chain） | **Solidity (CTF + FPMM)** + Python agent 工具链（Gnosis PMAT） | 链上 FPM M（bonding curve） | The Graph + Python SDK（prediction-market-agent） | Realitio oracle + Kleros 仲裁 | 仲裁/争议设计与我们 HumanHouse 最像 |

## 关键差异维度

### 撮合层（我们：无撮合，直接 `bet()` 记账）
- Polymarket / Kalshi 用 **CLOB（撮合引擎）**，是 Go/Rust/C++ 的主要去处，主要优化点：锁竞争、GC、尾延迟。
- Manifold / Omen / Azuro 用 **AMM / 服务器算价**，不需要低延迟撮合。
- **our project 现在没有撮合**——`bet()` 是纯记账。**不需要 Go/Rust 层**。

### 语言在地图上的位置
```
低并发/少运维                    高并发/强一致
  Manifold(TypeScript)   Omen(Solidity+Py)   Azuro(Solidity)   Polymarket(Go)   Kalshi(Go/Rust/C++)
        └── 我们在这里 ──────────────────────────────→ （未来若做撮合）
```

### 数据层
- Polymarket 用 ClickHouse 跑榜单/分析，是数据量到 `10^8` 才需要的。
- 我们数据规模（几百市场）直接用 `readContract` + 事件索引即可，未来量再大才需要 The Graph。

### 结算与仲裁
- Polymarket：UMA（任何人提案+保证金+挑战窗口）—— 我们逐步在接近（本轮自动广播 = 运营商自动广播）。
- Omen：Kleros 陪审团 —— 与我们 HumanHouse 选票仲裁思路一致。
- Kalshi：纯中心化，无争议流程 —— 我们比它多一层 HumanHouse，已超。

## 结论与建议

1. **语言不改**：our project 是「TS 全栈 + Solidity 链上核心」，与 Manifold 同思路，符合当前规模。
2. **值得逐步引入（按优先级，等有真实需求再上）**：
   - **The Graph 链上索引**：替代前端大量 `readContract` 轮询（关系型读路径成熟）。
   - **Python/keeper（可选）**：Gnosis PMAT 体系成熟，若做「自动结算 keeper / AI 分析」可直接复用。
   - **Go/Rust 撮合**：仅当未来做 CLOB 撮合。现在 YAGNI。
3. **架构上已经在正确方向**：off-chain 代签广播（本轮）+ on-chain 最终状态 + 链上仲裁 = 成熟市场的共同骨架。

## 附：参考来源（本表数据来源）

- Polymarket：官方招工（Go 主）、ClickHouse blog、Auditless research、CLOB V2 架构分析。
- Kalshi：echoloc tech stack、招工（Go/Rust/C++）。
- Manifold：GitHub monorepo（全 TypeScript + supabase 迁移）。
- Azuro：protocol docs、Messari、LiquidityTree 分析。
- Omen/Gnosis：Gnosis prediction-market-agent 仓库、Omen 2.0 提案。