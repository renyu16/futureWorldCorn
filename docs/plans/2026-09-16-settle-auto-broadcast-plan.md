# 结算自动广播 + 手动兜底 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 用户点「结算 YES/NO」时，服务端优先自动广播 `resolveMarket` 交易；失败则前端展示原始交易数据（复制 JSON / cast 命令）供手动广播。

**Architecture:** 服务端 `serve.mjs` 新增 `POST /api/settle` 路由：校验 body → ethers（懒加载）构造并签名 `resolveMarket(uint256,bool)` 交易 → 经 RPC 广播 → 返回 `{ok, txHash}` 或 `{ok:false, error}`。前端 `handleResolve` 改为两步：先调接口，成功显示 txHash（可点浏览器），失败/未配置/缺依赖时本地用 viem `encodeFunctionData` 生成 `{to, data}` 与 `cast` 命令供 COPY。合约不改，需链上把服务端 key 授权为 resolver。

**Tech Stack:** Node.js 原生 `http`（serve.mjs，零依赖 → ethers^6 可选懒加载）、React/Vite/viem（前端）、cast（手动兜底实测）。

---

## 前置事实（必须遵守）

- 服务端广播复用已有 `--rpc-upstream`（默认 `RPC_PROXY_UPSTREAM`，即 worldchain-sepolia Alchemy 公网），不带 `staticNetwork` 时 ethers 会先探测 chainId，4801 可被识别。
- ethers 用 ESM `await import('ethers')`，需 `deploy/webserver/package.json` 声明依赖；未安装时自动广播降级为 501，不影响静态服务。
- PM proxy（测试网）：`0x9cb69cb7da9677b3a122a6a4e402398a6df4a026`。
- 前端 build 命令：`cd frontend && npm run build`（先 tsc 再 vite）；测试：`npm test`（当前 82 用例全绿基线）。
- `start.sh` 已存在（nohup 起 serve.mjs），若 node_modules 缺失会在广播时触发 501 提示，无需改 start.sh 逻辑（graceful degradation），但会新增 `package.json`。
- Windows 环境：提交时有 LF→CRLF 警告，忽略即可。

---

## Task 1: 服务端依赖 + 环境变量模板

**Files:**
- Create: `deploy/webserver/package.json`
- Create: `deploy/webserver/.env.example`

**Step 1: 创建 `deploy/webserver/package.json`**

```json
{
  "name": "prediction-master-webserver",
  "private": true,
  "type": "module",
  "dependencies": {
    "ethers": "^6.13.0"
  }
}
```

**Step 2: 创建 `deploy/webserver/.env.example`**

```bash
# 结算自动广播（服务端代签 resolveMarket）
SETTLE_PRIVATE_KEY=0x...
# 与前端构建的 VITE_SETTLE_API_TOKEN 一致（静态包内可见，二次防线；真正防线是服务端私钥）
SETTLE_API_TOKEN=change-me-long-random-token
# 可选：PredictionMarket 代理地址覆盖，缺省回退测试网默认地址
# SETTLE_PREDICTION_MARKET_ADDRESS=0x...
```

**Step 3: 提交**

```bash
git add deploy/webserver/package.json deploy/webserver/.env.example
git commit -m "feat: settle webserver dep + env template"
```

---

## Task 2: serve.mjs — /api/settle 广播

**Files:**
- Modify: `deploy/webserver/serve.mjs`

**Step 1: 常量区新增配置读取**

在 `const args = parseArgs(...)` 之后加入：

```js
const SETTLE_PRIVATE_KEY = process.env.SETTLE_PRIVATE_KEY || '';
const SETTLE_API_TOKEN = process.env.SETTLE_API_TOKEN || '';
const SETTLE_PREDICTION_MARKET_ADDRESS =
  process.env.SETTLE_PREDICTION_MARKET_ADDRESS ||
  '0x9cb69cb7da9677b3a122a6a4e402398a6df4a026';
const SETTLE_TIMEOUT = 30000;
```

**Step 2: 新增 JSON body 读取辅助（`proxyRpc` 之后）**

```js
function readJsonBody(req, cb) {
  const chunks = [];
  req.on('data', (c) => chunks.push(c));
  req.on('end', () => {
    try {
      cb(JSON.parse(Buffer.concat(chunks).toString('utf8')));
    } catch {
      cb(null);
    }
  });
  req.on('error', () => cb(null));
}

function sendJson(res, status, obj) {
  send(res, status, JSON.stringify(obj), {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
  });
}
```

**Step 3: 新增 handleSettle**

```js
async function handleSettle(req, res) {
  if (req.method !== 'POST') return sendJson(res, 405, { ok: false, error: 'method not allowed' });
  const auth = (req.headers['authorization'] || '').trim();
  const expected = `Bearer ${SETTLE_API_TOKEN}`;
  if (!SETTLE_API_TOKEN || auth !== expected) {
    return sendJson(res, 401, { ok: false, error: 'unauthorized' });
  }
  readJsonBody(req, async (body) => {
    if (!body || typeof body.marketId !== 'number' || typeof body.result !== 'boolean') {
      return sendJson(res, 400, { ok: false, error: 'invalid body: { marketId: number, result: boolean }' });
    }
    const marketId = body.marketId;
    if (!Number.isInteger(marketId) || marketId < 1) {
      return sendJson(res, 400, { ok: false, error: 'invalid marketId' });
    }
    if (!SETTLE_PRIVATE_KEY) {
      return sendJson(res, 501, { ok: false, error: 'settle not configured: missing SETTLE_PRIVATE_KEY' });
    }
    let ethers;
    try {
      ethers = await import('ethers');
    } catch {
      return sendJson(res, 501, { ok: false, error: 'settle not configured: ethers not installed (run "npm install" in deploy/webserver)' });
    }
    try {
      const provider = new ethers.JsonRpcProvider(rpcUpstream, undefined, { staticNetwork: true });
      const wallet = new ethers.Wallet(SETTLE_PRIVATE_KEY, provider);
      const iface = new ethers.Interface(['function resolveMarket(uint256 marketId, bool result)']);
      const data = iface.encodeFunctionData('resolveMarket', [marketId, result]);
      const tx = await wallet.sendTransaction({ to: SETTLE_PREDICTION_MARKET_ADDRESS, data });
      const receipt = await Promise.race([
        tx.wait(),
        new Promise((_, reject) => setTimeout(() => reject(new Error('tx wait timeout')), SETTLE_TIMEOUT)),
      ]);
      return sendJson(res, 200, { ok: true, txHash: receipt.hash || tx.hash });
    } catch (e) {
      console.error(`settle error: ${e?.message || e}`);
      return sendJson(res, 200, { ok: false, error: 'broadcast failed: ' + (e?.shortMessage || e?.message || 'unknown') });
    }
  });
}
```

**Step 4: 路由接入**

在 `createServer` 回调中、`if (urlPath === RPC_PATH)` 之前加入：

```js
  if (urlPath === '/api/settle') return handleSettle(req, res);
```

**Step 5: 语法检查 + 分支冒烟**

Run:
```powershell
cd deploy/webserver
node --check serve.mjs
```
Expected: 无输出 = 语法 OK。

本地起服务（临时 shell，用端口 8199）：
```powershell
node serve.mjs --port 8199
```
另一终端验证（未配置 key/token 时）：
```powershell
# 无 token → 401
curl.exe -s -X POST http://127.0.0.1:8199/api/settle -H "Content-Type: application/json" -d "{\"marketId\":1,\"result\":true}"
# → {"ok":false,"error":"unauthorized"}
```
Expected: 401。然后 Ctrl+C 停掉冒烟进程。

**Step 6: 提交**

```bash
git add deploy/webserver/serve.mjs
git commit -m "feat: add POST /api/settle auto-broadcast endpoint"
```

---

## Task 3: 前端配置项

**Files:**
- Modify: `frontend/src/config.ts`
- Modify: `frontend/src/vite-env.d.ts`
- Modify: `frontend/.env.example`

**Step 1: config.ts 新增导出**（在 `PROJECT_ID` 附近/`EXPLORER_URL` 后均可）

```ts
/** 结算自动广播 API（VITE_SETTLE_API_URL，缺省同源 /api/settle） */
export const SETTLE_API_URL = pickStr('VITE_SETTLE_API_URL', '/api/settle')

/** 结算自动广播 Bearer token（VITE_SETTLE_API_TOKEN；为空则跳过自动广播直接手动兜底） */
export const SETTLE_API_TOKEN = pickStr('VITE_SETTLE_API_TOKEN', '')
```

**Step 2: vite-env.d.ts 增加声明**

```ts
  /** 结算自动广播 API 地址（缺省 /api/settle） */
  readonly VITE_SETTLE_API_URL?: string
  /** 结算自动广播 Bearer token（为空则跳过自动广播） */
  readonly VITE_SETTLE_API_TOKEN?: string
```

**Step 3: frontend/.env.example 追加**

```bash
# ---- 结算自动广播（可选，不配则始终走手动兜底）----
# VITE_SETTLE_API_URL=/api/settle
# VITE_SETTLE_API_TOKEN=
```

**Step 4: 提交**

```bash
git add frontend/src/config.ts frontend/src/vite-env.d.ts frontend/.env.example
git commit -m "feat: frontend settle api config"
```

---

## Task 4: 前端 MarketDetail — 自动广播为主、手动兜底

**Files:**
- Modify: `frontend/src/pages/MarketDetail.tsx`

**Step 1: imports**

- 增加 `import { encodeFunctionData } from 'viem'`
- 增加 `import { SETTLE_API_URL, SETTLE_API_TOKEN } from '../config'`（并入已有 config import 行）

**Step 2: state 新增**

组件内新增：

```tsx
  const [settle, setSettle] = useState<{
    status: 'idle' | 'pending' | 'ok' | 'manual'
    txHash?: string
    error?: string
  }>({ status: 'idle' })
```

**Step 3: 替换 handleResolve**

将原 `handleResolve`（约 209-219 行）替换为：

```tsx
  const handleResolve = async (win: boolean) => {
    if (!SETTLE_API_TOKEN) {
      setSettle({ status: 'manual' })
      return
    }
    setSettle({ status: 'pending' })
    try {
      const res = await fetch(SETTLE_API_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${SETTLE_API_TOKEN}` },
        body: JSON.stringify({ marketId, result: win }),
      })
      const payload = await res.json().catch(() => null) as { ok?: boolean; txHash?: string; error?: string } | null
      if (res.ok && payload?.ok && payload.txHash) {
        setSettle({ status: 'ok', txHash: payload.txHash })
        toast('结算已自动广播', 'info')
        queryClient.invalidateQueries({ queryKey: ['readContract'] })
        return
      }
      setSettle({ status: 'manual', error: payload?.error })
    } catch (e: any) {
      setSettle({ status: 'manual', error: e?.message || '网络错误' })
    }
  }
```

**Step 4: 手动兜底编码与复制**

新增函数（handleResolve 后）：

```tsx
  const buildManualSettle = (win: boolean) => {
    const data = encodeFunctionData({
      abi: predictionMarketABI,
      functionName: 'resolveMarket',
      args: [BigInt(marketId), win],
    })
    return {
      payload: JSON.stringify({ to: PREDICTION_MARKET_ADDRESS, data, value: '0x0' }, null, 2),
      castCmd: `cast send ${PREDICTION_MARKET_ADDRESS} "resolveMarket(uint256,bool)" ${marketId} ${win}`,
    }
  }
  const [manual, setManual] = useState<{ payload: string; castCmd: string } | null>(null)

  const copyText = async (text: string, label: string) => {
    try {
      await navigator.clipboard.writeText(text)
      toast(`${label} 已复制`, 'info')
    } catch {
      toast('复制失败', 'error')
    }
  }
```

**Step 5: 结算区 JSX 改造**

把原「结算市场」区块（约 308-321 行）替换为：

```tsx
          {isOpen && canResolve && deadlinePassed && (
            <div className="space-y-3 border-t border-border pt-4">
              <h3 className="font-semibold">结算市场</h3>
              {settle.status === 'ok' ? (
                <div className="space-y-2 rounded-lg bg-muted/10 p-3 text-sm">
                  <p className="text-green-600">已自动广播：{settle.txHash}</p>
                  <a
                    href={`${EXPLORER_URL}/tx/${settle.txHash}`}
                    target="_blank"
                    rel="noreferrer"
                    className="inline-flex items-center gap-1 text-primary underline"
                  >
                    在区块浏览器查看
                    <svg className="h-3 w-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M7 17L17 7M7 7h10v10"/></svg>
                  </a>
                </div>
              ) : serve.status === 'pending' ? (
                settle.status === 'pending' && (
                  <p className="flex items-center gap-2 text-sm text-muted">
                    <Loader2 className="h-4 w-4 animate-spin" /> 正在自动广播结算交易...
                  </p>
                )
              ) : settle.status === 'manual' ? (
                <div className="space-y-2">
                  {settle.error && <p className="text-xs text-amber-600">自动广播失败：{settle.error}</p>}
                  <p className="text-sm text-muted">自动广播不可用，请选择结算结果并手动广播。</p>
                  <div className="flex gap-2">
                    <Button variant="outline" className="flex-1" onClick={() => setManual(buildManualSettle(true))}>结算 YES 胜</Button>
                    <Button variant="outline" className="flex-1" onClick={() => setManual(buildManualSettle(false))}>结算 NO 胜</Button>
                  </div>
                  {manual && (
                    <div className="space-y-2 rounded-lg bg-muted/10 p-3">
                      <textarea readOnly value={manual.payload} rows={6}
                        className="w-full resize-y rounded border bg-background p-2 font-mono text-xs" />
                      <div className="flex flex-wrap gap-2">
                        <Button size="sm" onClick={() => copyText(manual.payload, '交易数据')}>复制交易数据(JSON)</Button>
                        <Button size="sm" variant="outline" onClick={() => copyText(manual.castCmd, 'cast 命令')}>复制 cast 命令</Button>
                      </div>
                    </div>
                  )}
                </div>
              ) : (
                <div className="space-y-3">
                  <p className="text-sm text-muted">截止时间已过，请选择获胜结果。优先服务端自动广播，失败可手动广播。</p>
                  <div className="flex gap-2">
                    <Button className="flex-1" variant="outline" onClick={() => handleResolve(true)}>结算 YES 胜</Button>
                    <Button className="flex-1" variant="outline" onClick={() => handleResolve(false)}>结算 NO 胜</Button>
                  </div>
                </div>
              )}
            </div>
          )}
```

注意 JSX 条件别写错（`settle.status`），Task 4 Step 5 里的一处 `serve.status` 是手误，实现时统一用 `settle.status`。

**Step 6: 构建 + 单测**

Run:
```powershell
cd frontend
npm run build
```
Expected: tsc 无错误、vite build ok。
Run:
```powershell
npm test
```
Expected: 现有用例全通过（不回退）。

**Step 7: 提交**

```bash
git add frontend/src/pages/MarketDetail.tsx
git commit -m "feat: settle with server auto-broadcast + manual fallback copy"
```

---

## Task 5: 服务端手动验证

**Files:**
- 本地环境（不提交）

**Step 1: 安装 ethers 并自测 encode**

Run:
```powershell
cd deploy/webserver
npm install --omit=dev
node --input-type=module -e "const {ethers}=await import('ethers'); const iface=new ethers.Interface(['function resolveMarket(uint256,bool)']); console.log(iface.encodeFunctionData('resolveMarket',[1,true]))"
```
Expected: 打印形如 `0x57bde4460000...0001` 的 calldata（开头 selector `0x57bde446`，后面 32 字节 marketId=1、32 字节 result=true）。`resolveMarket` selector 实测定为 `0x57bde446`（2026-09-17 验证），与前端手动兜底的 `cast send ... "resolveMarket(uint256,bool)"` 命令一致。

**Step 2: cast 校验 selector（可选）**
Run:
```powershell
cast sig "resolveMarket(uint256,bool)"
```
Expected: `0x57bde446`（2026-09-17 实测 ethers encode 输出开头，前端 manual 兜底文案据此确认）。

**Step 3: 端到端（真实 key，谨慎）**
- 设置 `.env`：`SETTLE_PRIVATE_KEY`、`SETTLE_API_TOKEN`。
- 前置：链上 owner 已 `setResolver(0xbaD893..., true)`（发布 `feat` 后由 owner key 执行，见 Task 6）。
- curl 一个「已到期未结算」的市场：
```powershell
curl.exe -s -X POST http://127.0.0.1:8199/api/settle -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" -d "{\"marketId\":1,\"result\":true}"
# {ok:true, txHash:0x...}
```
Expected: `ok:true`，浏览器可查。
- 手动兜底链路：停服务 / 改错 token，前端走 manual 路径，用复制出的 JSON + `cast send --private-key $KEY ...` 实测广播。

**Step 4: 提交 lockfile（仅当 package-lock.json 生成）**

```bash
git add deploy/webserver/package-lock.json
git commit -m "chore: lock ethers for settle auto-broadcast"
```

---

## Task 6: 链上授权 resolver（ops，需用户配合确认）

**Files:** 无代码

- owner key（AI_DEV_A）在测试网把服务端广播 key（AI_DEV_B `0xbaD8931A4A6a25710644BcA9F9d07680ABaB1dA5`）授权为 resolver：
```bash
cast send 0x9cb69cb7da9677b3a122a6a4e402398a6df4a026 "setResolver(address,bool)" 0xbaD8931A4A6a25710644BcA9F9d07680ABaB1dA5 true --rpc-url http://8.141.100.69:8085/rpc --private-key $OWNER_KEY
```
- 验证：`cast call 0x9cb69... "resolvers(address)" 0xbaD8... --rpc-url ...` 返回 `true`。

---

## 收尾检查清单

- [ ] `serve.mjs`：`node --check` 通过；401/400/501 分支 curl 验证
- [ ] 前端 `npm run build` + `npm test` 全绿
- [ ] 链上 `resolvers(0xbaD8…) == true`
- [ ] `/api/settle` 对测试网可结算市场实测 `ok:true` 且 tx 可查
- [ ] 手动兜底（前端 manual 面板复制 JSON / cast 命令）实测可广播
- [ ] 3 个 commit 已入 main，推送 origin/main（AGENTS.md 约定）
- [ ] `.env.example` 新增项已提交；真实 `.env`（服务端/frontend）不入库