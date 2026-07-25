# World ID 集成设计

## 概述

将 HumanHouse 中的 `_verifyWorldId()` 占位符替换为真实的 World ID v3 ZKP 验证，实现一人一票的 sybil resistance。

## 架构

```
Frontend (IDKit JS)                     HumanHouse                     WorldIdRouter (World Chain)
      │                                      │                              │
      │  vote(disputeId, support,            │                              │
      │       root, nullifierHash,           │                              │
      │       proof[8])                      │                              │
      │──────────────────────────────────────→                              │
      │                                      │  verifyProof(root, groupId,  │
      │                                      │    signalHash, nullifier,    │
      │                                      │    externalNullifier, proof) │
      │                                      │─────────────────────────────→│
      │                                      │←─────────────────────────────│
      │                                      │                              │
      │                                      │  check nullifierUsed[dispute][nullifier]
      │                                      │                              │
      │←─ emitted VoteCast ──────────────────│                              │
```

## 合约改动

### HumanHouse.sol

**新增 import:**
- `IWorldID` 接口 — `worldIdRouter.verifyProof()`
- `ByteHasher` 工具库 — `hashToField()` 函数

**构造函数变更:**
```solidity
constructor(
    address _cornToken,
    address _predictionMarket,
    uint256 _disputeDeposit,
    IWorldID _worldId,
    string memory _appId,
    string memory _actionId
)
```

- `_worldIdRouter`: World Chain 上的 WorldIdRouter 地址
- `_appId`: 开发者门户注册的 app ID（先用占位符）
- `_actionId`: 操作 ID（例如 `"human_house_vote"`）
- `externalNullifierHash` = `hashToField(hashToField(appId) + actionId)`

**vote() 签名变更:**
```solidity
function vote(
    uint256 disputeId,
    bool support,
    uint256 root,
    uint256 nullifierHash,
    uint256[8] calldata proof
) external
```

- `root`, `nullifierHash`, `proof` 由前端 IDKit 生成
- `signal` = `msg.sender`（将投票与钱包地址绑定）
- `verifyProof()` 成功后，标记 `nullifierUsed[disputeId][nullifierHash] = true`
- 移除对 `hasVoted[disputeId][address]` 的依赖（由 nullifier 替代）

**删除:**
- `hasVoted` mapping（由 `nullifierUsed` 替代）
- `_verifyWorldId()` 函数（内联到 `vote()` 中）

### Signal 设计

- `signalHash = hashToField(abi.encodePacked(msg.sender))`
- 绑定 ZKP 到调用者地址，防止 proof 被重放

### ExternalNullifier 设计

- `externalNullifierHash = hashToField(abi.encodePacked(hashToField(abi.encodePacked(appId)), actionId))`
- 其中 `actionId` 为字符串 `"human_house_vote"`（可在开发者门户配置）

### groupId

- 固定为 `1`（Orb，是链上唯一支持的凭证类型）

## 测试方案

### MockWorldIdRouter

部署一个 Mock 合约用于测试，始终 `verifyProof` 通过：
```solidity
contract MockWorldIdRouter {
    function verifyProof(...) external view {
        // Always succeeds in test
    }
}
```

在单元测试中用 Mock 替换真实 WorldIdRouter，入参校验：
- `root == 0` 时恶意参数应 revert（Mock 可选择性 revert）
- `nullifierHash` 重复应 revert

### 测试更新

所有 11 个现有 `HumanHouseTest` 测试需要：
1. 部署 MockWorldIdRouter
2. 新增 `appId` 和 `actionId` 参数传入 HumanHouse 构造函数
3. `vote()` 调用增加 `root`, `nullifierHash`, `proof` 参数
4. 增加 `test_DuplicateNullifier` 测试
5. 增加 `test_InvalidProof` 测试

## 前端改动

1. 新增 `IWorldID` / WorldIdRouter ABI 到 `abi.ts`
2. `HumanHouse.vote()` 调用增加 `root`, `nullifierHash`, `proof` 参数
3. 未来集成 IDKit JS widget 时生成 ZKP

## 不做

- v4 接口（等生态成熟再说）
- 用户注册流程（验证放在每次 vote 中较简单）
- 真实 Orb 集成（目前无法获取，用 Mock 和占位符地址替代）
