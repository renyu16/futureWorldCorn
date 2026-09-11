```mermaid
flowchart TD
    subgraph 创建
        A[Owner / MarketCreator] -->|createMarket\(question, deadline, feeBps\)| B[市场上线<br/>marketCount++<br/>feeBps 确定]
        B --> C{市场状态：Open}
    end

    subgraph 下注
        C --> D[用户浏览市场]
        D --> E[选择 YES 或 NO<br/>输入 CORN 数量]
        E --> F{首次下注?}
        F -->|是| G["token.approve(PM, ∞)"]
        F -->|否| H["bet\(marketId, outcome, amount\)"]
        G --> H
        H --> I["CORN 转入合约<br/>记账 sharesYes / sharesNo"]
        I --> J["用户可重复下注<br/>（直到 deadline）"]
        J --> C
    end

    subgraph 判定胜负
        C -->|"deadline 到期<br/>block.timestamp ≥ deadline"| K[Resolver / Owner 调用<br/>resolveMarket\(id, result\)]
        K --> L{result = ?}
        L -->|true| M[市场结果：YES 胜]
        L -->|false| N[市场结果：NO 胜]
        M --> O["市场状态：Resolved"]
        N --> O
    end

    subgraph "结算（claimReward）"
        O --> P[YES 持有者 / NO 持有者<br/>调用 claimReward\(marketId\)]

        P --> Q{"空边获胜?<br/>（outcomeYes=0 且 result=true<br/>或 outcomeNo=0 且 result=false）"}
        Q -->|"否（双边都有下注）"| R["fee = losingPool × feeBps / 10000"]
        Q -->|"是（单边，空边赢）"| S["无真正赢家<br/>按份额全额退款<br/>不收手续费"]

        R --> T["rewardPool = losingPool - fee"]
        T --> U["reward = userShares × rewardPool / winningPool + userShares"]
        U --> V["fee → feeCollector<br/>reward → 用户"]
        S --> W["refund = userShares<br/>→ 全额退还用户"]

        V --> X["领取完成<br/>claimed = true"]
        W --> X
    end

    subgraph "特殊情况：单边市场"
        direction TB
        Z1["只有 YES 下注<br/>（outcomeNo=0）"] --> Z2{"结算结果?"}
        Z2 -->|result=true（YES 赢）| Z3["用户拿回本金 1:1<br/>无利润（无败池可分）<br/>平台 fee=0"]
        Z2 -->|result=false（NO 赢）| Z4["空边获胜 → 退款路径<br/>全额退还本金<br/>防止资金锁死"]
    end

    style S fill:#fff3cd,stroke:#ffc107
    style Z4 fill:#f8d7da,stroke:#dc3545
    style V fill:#d4edda,stroke:#28a745
    style W fill:#d4edda,stroke:#28a745
```
