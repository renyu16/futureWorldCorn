# Admin 面板设计（2026-09-17）

## 背景与目标

为预测大师前端新增 `/admin` 长期管理面板，用于运营者/属主在链上执行管理操作：

- **Resolver 授权管理**（`setResolver`，仅 Owner）
- **结算交易**（`resolveMarket`，Owner + Operator）
- **只读信息**（owner / 链 ID / 合约地址 / 身份角色）

约束与已定决策：

- **必须连接钱包**才可作为操作身份（否决"输入私钥/浏览器签名"方案——私钥有任何落到网络/页面的路径都不接受，钱包插件是唯一合法 key 载体）。
- **签名与广播全部走 wagmi 钱包**，transport 用现有 RPC（`/rpc` 代理）。`serve.mjs` 后端**零改动**。`/api/settle`（MarketDetail 服务端自动广播）与面板并行不冲突。
- 前端角色判定**只是 UX 层**；真实安全边界在链上合约（`onlyOwner` / `resolvers[msg.sender]`）。

## 角色矩阵（链上实时判定）

| 角色 | 判定 | Admin 入口 | 可用功能 |
|------|------|-----------|---------|
| Owner | `address == owner()` | ✅ | 只读 + Resolver 管理 + 结算 |
| Operator | `resolvers[address]` | ✅ | 只读 + 结算（无 Resolver 管理）|
| 普通用户 | 其他 | ❌ 无入口；直达 `/admin` 显示"无权限" | 无 |
| 未连接钱包 | — | ❌ | 提示"请先连接钱包" |

## 页面结构

1. **只读信息区**：`CHAIN_ID`/链名、PM 合约地址、`owner()`、当前身份角色标签；标注"角色判定仅供 UX，真实权限在链上"；最佳实践提示（owner 冷 key / resolver 热 key 分离）。
2. **Resolver 管理**（仅 Owner）：输入地址 → 读 `resolvers[addr]` → 「授权 / 撤销」。注意：**合约无 enumerable，只能按地址查询，不能枚举列表**。撤销旁加警示文字。
3. **结算区**（Owner + Operator）：输入 marketId → 读市场 status/deadline → 选 YES/NO → 交易前四连确认（操作 wallet 地址、链 ID、合约地址、目标市场 status）。
4. 结算完成后显示 txHash + 浏览器链接 + **纠错流程提示**（disputeResolve 可纠正，先纠错后撤销 bad key）。

## 关键流程

```
连接钱包 → 读 chainId/owner/resolvers → 判定角色 → 按角色显隐 UI
操作区校验：connectedChainId === CHAIN_ID（不符禁用按钮）
writeContract → 钱包弹窗 → 用户核对合约地址+函数签名 → 广播 → 轮询回执 → 提示
```

## 漏洞分析及缓解

| 级别 | 漏洞 | 缓解 |
|------|------|------|
| H1 | resolver 可下注后自行结算（自买自批）| 这是合约设计属性；面板将其定位为高信任操作者，结算区四连确认 + 提示隔离 key。不引入额外合约改动 |
| H2 | `disputeResolve` 可将已结算结果翻转；bad key 泄露后仅撤销无法回滚已上链结果 | 结算区提示：先用备用 resolver/owner key 调 `disputeResolve` 纠正，再 `setResolver(badKey,false)` 撤销 |
| M1 | 前端 RPC 可被 `localStorage.app_rpc_url` 劫持 → 角色/状态显示被伪造 | 明确"唯一可信确认点是钱包弹窗中的合约地址+函数签名"；角色徽标/预演仅供参考 |
| M2 | 跨链连接（4801 vs 480）导致打错/失败 | 交易前强制 `chainId === CHAIN_ID`，不符禁用按钮并提示切换 |
| L1 | 隐藏 `/admin` 入口 ≠ 安全边界，绕开 UI 直接调用合约同样生效 | 明确 UI 门禁仅职责分离；安全依赖链上 `onlyOwner`/`resolvers` |
| L2 | resolver 列表无法枚举（`mapping` 无 enumerable）| 面板改为"按地址查询"模式 |
| L3 | owner key 单点（可 upgrade、改 fee、reset market）| 只读信息区展示冷热 key 分离最佳实践；主网上线前考虑 Safe 多签+timelock（本期不做）|

无漏洞项已复核：deadline 衔接（bet `<` deadline、resolve `>=` deadline）、结算后 `bet` 被 `status==Open` 拦截，无后门补仓。

## 技术方案

- **前端**：`frontend/src/` 新增 `pages/Admin.tsx`；`contracts/abi.ts` 补 `setResolver(address,bool)`；`App.tsx` 按角色显隐 nav 中 Admin 入口并注册 `/admin` 路由；`hooks/useAdmin.ts`（可选）封装 `useWriteSetResolver`。
- **交易执行**：wagmi `useWriteContract` + `writeContractAsync`；读取用 `useReadContract` / `usePublicClient.readContract`（读市场 struct 需 tuple ABI 或 `markets(uint256)` 分段读取，复用 MarketDetail 既有做法）。
- **校验**：`frontend` `npm run build`（tsc + vite）+ `npm test`（vitest，现有 82 用例基线 + 新增角色判定纯函数用例）。
- **后端**：`deploy/webserver/serve.mjs` 零改动。
- **手动验收**：连接 owner 钱包看全量功能；连 operator 钱包看结算、无管理；连普通钱包看无权限；切错链看按钮禁用。

## 明确不做（YAGNI）

- 不引入多签/timelock 合约改造（记为主网上线前增强）。
- 不做 resolver 枚举 / 事件索引 / 审计日志页（暂以浏览器 + 区块浏览器兜底）。
- 不改合约、不改后端。

## 实现状态（2026-09-17）

已实现：`/admin` 路由 + 角色门禁（owner/operator/none/unconnected/unknown）、只读信息区、Resolver 授权管理（仅 owner）、市场结算（owner+operator，四连确认 + 链守卫 + 不存在/非可结算保护）。纯函数 `src/lib/admin.ts` 有单测。详见 `2026-09-17-admin-panel-plan.md`。