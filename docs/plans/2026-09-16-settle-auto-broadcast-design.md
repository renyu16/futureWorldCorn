# 结算自动广播 + 手动兜底 — 设计文档

日期：2026-09-16
状态：已获用户批准（方案 A）

## 背景与问题

- 市场到期后需要 `resolveMarket(marketId, result)` 才能进入领奖阶段。
- 当前该步骤只能由 owner / resolver 账号通过钱包或 `cast send` 手动广播，操作繁琐。
- 目标：**先自动广播（服务端代签），失败再退回手动复制原始交易数据**，而不是一上来就让用户手动复制。

## 需求确认（与用户已对齐）

1. 结算动作由服务端持 key 自动广播（类似 WalletConnect 的自动广播体验）。
2. 服务端自动广播调取失败时，前端展示「复制交易数据」供手动广播（cast send / 钱包）。
3. 主账号（owner）始终可结算；主账号可授权/取消任意子账号（resolver）结算 —— 合约 `setResolver` 已支持，无需改动。
4. 服务端 key 轮换：链上 `setResolver` 撤旧/授新 + 服务器 `.env` 更新即可。
5. 多运营者：平台系统 key（服务端）与运营者各自钱包直签并存，互不冲突。

## 方案选择：A —— ethers 集成进 serve.mjs

对比过独立 cast/bot 进程（方案 B）：

- 页面按钮点击是**同步请求**，只有跑在 Web 同链路内的服务端能即时响应；本地 cast bot 无法被页面触达。
- A 单进程单部署单元，沿用现有 `start.sh/stop.sh`，仅多一次 `npm install`。
- B 的「定时自动结算 keeper」形态与「点击即播」交互不符，留作未来可选增强。

结论：本期做 A；轮询 auto-keeper 记为后期可选增强（不进入本期范围）。

## 架构总览

```
用户点击「结算 YES/NO」            （仅 owner/resolver 前端可见，canResolve 逻辑不变）
  │
  ▼
POST /api/settle   { marketId, result }
  │   服务端（持有 SETTLE_PRIVATE_KEY，ethers 懒加载）
  ├─ 成功 → 签名广播 resolveMarket → 返回 { ok: true, txHash }
  │        前端显示「已广播」+ 区块浏览器链接 + refetch
  │
  └─ 失败/未配置/缺依赖 → 返回 { ok: false, error }
        前端本地用 viem encodeFunctionData 编码 resolveMarket → 显示原始交易数据
        「复制交易数据」→ 用户手动广播（cast send …）
```

## 服务端改动（deploy/webserver/serve.mjs）

- 新增 `POST /api/settle` 路由：
  - 校验：仅在 `urlPath === '/api/settle'`、`req.method === 'POST'`、`Content-Type: application/json` 时处理。
  - Body：`{ marketId: number, result: boolean }`。
  - 鉴权：`Authorization: Bearer <SETTLE_API_TOKEN>` 必须与 `.env` 中 `SETTLE_API_TOKEN` 匹配（常量时间比较，简单严格字符串比较即可）；未配置 token 视为未启用自动广播。
  - 需要 `SETTLE_PRIVATE_KEY` 且 ethers 可加载，否则返回 501（未配置）。
  - 构造 `resolveMarket(uint256,bool)` 交易 → 签名 → 使用 RPC（复用 `--rpc-upstream`，即 `RPC_PROXY_UPSTREAM`）广播。
  - 成功：`200 { ok: true, txHash }`；失败：`200 { ok: false, error }`（业务失败不暴露内部 key 相关信息）。
- ethers：**懒加载**（`await import('ethers')`，6.x）。无 node_modules 时自动广播不可用但 serve.mjs 正常运行 → 前端退回手动兜底（graceful degradation）。
- 新增 `deploy/webserver/package.json`：依赖 `ethers ^6`。
- 新增 `deploy/webserver/.env.example`：列出 `SETTLE_PRIVATE_KEY`、`SETTLE_API_TOKEN`、`PREDICTION_MARKET_ADDRESS`。
- `start.sh` 增加依赖检查：`node_modules` 缺失且存在 package.json 时提示（或自动 `npm install --omit=dev`）。
- PREDICTION_MARKET_ADDRESS 允许 env 覆盖：`SETTLE_PREDICTION_MARKET_ADDRESS`，缺省回退到兼容当前测试网的默认地址。

## 前端改动（frontend/src/pages/MarketDetail.tsx）

- `handleResolve` 改为两步：
  1. `fetch('/api/settle', { method:'POST', headers:{ 'Content-Type':'application/json', Authorization:`Bearer ${SETTLE_API_TOKEN}` }, body: JSON.stringify({ marketId, result }) })`。
     - 配置项 `VITE_SETTLE_API_URL`（默认 `/api/settle`）、`VITE_SETTLE_API_TOKEN`（可选，为空则直接跳过自动广播走手动兜底）。
  2. 成功（`ok:true`）：toast「已广播」+ 显示 txHash 与浏览器链接（EXPLORER_URL + `/tx/` + hash）+ `refetch`。
  3. 失败：展开手动兜底区域 —— 用 viem `encodeFunctionData`（`resolveMarket` selector + args）生成 `{ to, data, value: '0x0' }`，展示「复制交易数据」按钮 + `cast send` 示例命令。
- 保留 `canResolve`（owner / resolver）控制结算区显示，不变。
- 结算成功后 keep 30s 轮询 / refetch 使状态更新（沿用现有 forceUpdate 机制）。

## 配置与密钥

- 服务端 `.env`：
  - `SETTLE_PRIVATE_KEY=0x…`（= AI_DEV_B bot key，需链上授权为 resolver）
  - `SETTLE_API_TOKEN=<随机长串>`
  - `SETTLE_PREDICTION_MARKET_ADDRESS=0x…`（可选覆盖）
- 前端构建环境 `frontend/.env.example`：
  - `VITE_SETTLE_API_URL=/api/settle`
  - `VITE_SETTLE_API_TOKEN=`
- 前端该 token 会在静态包里可见 —— 属「二次防线」，真正防线是服务端私钥 + 页面可见性控制（单运营者模式可接受的权衡，已在设计中说明）。若未来多运营者且页面公开，应改用临时登录态签发，不在本期范围。

## 链上授权（ops，非代码）

- 服务端所选 key（如 AI_DEV_B）需先由 owner 调用 `setResolver(key, true)` 才能广播成功。
- 轮换：owner `setResolver(旧,false)` + `setResolver(新,true)` + 更新 `.env` + 重启。owner 本身始终可结算，不存在锁死窗口。

## 错误处理

- 服务端：非法 JSON / 缺字段 / 类型错 → 400；未配置 key/token/dep → 501；RPC 广播失败 → `{ ok:false, error }`（不泄漏私钥/不行细节）。
- 前端：网络错误、`ok:false`、懒加载不可用（501）都走同一手动兜底路径；兜底编码用本地 viem，不依赖服务端存活。

## 测试

- 服务端：本地 `node serve.mjs` 起服务，curl 校验 —— 未配置 key → 501；body 校验 → 400；`Authorization` 缺失/错误 → 401；配好 key 后（或用 Mock RPC）→ 正常广播路径。自动广播路径在测试网用真实 key 谨慎验证（只对可结算市场）。
- 前端：`npm test`（现有 82 用例不回退）+ `npm run build`（tsc 通过）。
- 手动兜底：`cast send` 使用复制出的交易数据实测广播。

## 不在本期范围

- 轮询 auto-keeper（定时自动结算所有到期市场）。
- 权限化 propose + 挑战窗口（Polymarket 式），后期按 B 方向再做。
- 多运营者独立 key 的服务器端多 key 管理。