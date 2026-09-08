# E2E 自动化测试清单：App → WalletConnect v2 → 创建市场（链上验证）

> 场景：真机模拟（Android 模拟器 AVD `PriceSnap_Test`）运行「预测大师」Flutter App，
> 通过 WalletConnect v2 配对 Node 自动钱包，在 App 内提交「创建市场」表单，
> 触发 `eth_sendTransaction` → 自动签名广播上链 → 链上 receipt 验证。
> 2026-09-08 已跑通，本文固化可重复步骤。链：World Chain Sepolia **4801**，
> RPC `http://8.141.100.69:8085/rpc`。

## 一、前提

| 项 | 值 |
|---|---|
| 模拟器 | AVD `PriceSnap_Test`, **必须带 `-http-proxy http://127.0.0.1:7897` 启动**（relay WSS 走 SLIRP 透明代理；Dart WebSocket 不读 Android 系统代理） |
| Android 全局代理 | `adb shell settings put global http_proxy 10.0.2.2:7897` |
| App 包名 | `com.predictionmaster.future_world_corn_mobile`（勿用旧的 `com.predictionmaster.app`） |
| APK | `mobile/build/app/outputs/flutter-apk/app-debug.apk` |
| 测试钱包 | `0x8fd379246834eac74B8419FfdA202CF8051F7A03`，私钥 `WC_DEV_PK`（默认 `0xaaa…`64 个 a），已授权 `marketCreator`，**需有 WLD 余额**（Owner `0xDeF213…` 用 `cast send --value` 打币） |
| 钱包侧脚本 | `scripts/e2e/`：`test_e2e.js`（常驻,无 120s 超时）、`proxied_ws.cjs`（Bearer auth）、`run_e2e.cmd` |
| relay | `wss://relay.walletconnect.org`，projectId `38cfd0c495d4727d3d7e51ec3824a052` |
| foundry | `~/.foundry/bin/forge(cast).exe`（不在 PATH，用全路径） |

## 二、E2E 一键流程（已跑通）

```powershell
# 0) 确保模拟器已用 -http-proxy 参数启动、App 装着、代理设好；看 relay 是否连上：
adb -s emulator-5554 logcat -d | Select-String "RelayClient"
#    （应看到 Connected to relay wss://relay.walletconnect.org）

# 1) 后台抓 logcat，点 App「连接钱包」→ 点 MetaMask 卡片，15~22s 后取 openRedirect 里的 uri= 并 decode
#    （详见下方【URI 抓取】；结果写入 %TEMP%\opencode\last_uri.txt）

# 2) 启动常驻自动钱包（配对 + approve + 常驻等请求）：
cmd /c start /b scripts\e2e\run_e2e.cmd "<wc:...>"
#    日志：scripts\e2e\e2e.log（== PAIRED / == SESSION APPROVED / == SESSION_REQUEST / == SIGNED / == BROADCAST txHash / == RESPONDED）

# 3) App：更多 → 创建市场 → 填表（问题/截止日期/时间/费率 200）→ 点「签名并广播」

# 4) 链上验证：
~/.foundry/bin/cast receipt --rpc-url http://8.141.100.69:8085/rpc "<txHash>"
#    status=1 (success) 且日志含 MarketCreated topic（含 marketId）
```

## 三、关键坐标（1080×2400，稳定值）

| 操作 | 坐标 |
|---|---|
| 底部 Tab「更多」 | (945, 2263) |
| 更多页「创建市场」 | (540, 844) |
| 网络设置「连接钱包 (WalletConnect)」 | (540, 1263) |
| 网络设置「断开钱包」 | (540, 1475) |
| 钱包选择弹窗 MetaMask 卡片 | 每次 dump 取 bounds（近期中心 (540, 1696) 或 (540, 2043)） |
| 创建市场表单-问题框 | (540, 636)→输入→keyevent 4 |
| 创建市场表单-截止日期字段 | (300, 850)→日期选择器 |
| 日期选择器选 9 月 9 日 | (540, 1221)；OK=(908, 1877) |
| 时间字段 | (650, 860)→时间选择器；默认 11:59 PM；OK=(863, 1751) |
| 费率框 | (540, 1060)→输入 200→keyevent 4 |
| 「签名并广播」 | (540, 1290) |

## 四、URI 抓取（AppKit 1.9.0 + relay 已连的前提）

```powershell
$d = "$env:TEMP\opencode\log_uri.txt"
Start-Job -ScriptBlock { param($a,$o) & $a -s emulator-5554 logcat > $o } -ArgumentList $adb,$d | Out-Null
adb -s emulator-5554 shell input tap 540 1696   # MetaMask 卡片，坐标每次 dump 取
Start-Sleep 18
Stop-Job * | Out-Null
$line = (Get-Content $d | Where-Object { $_ -match "openRedirect" } | Select -Last 1)
$uri  = [System.Uri]::UnescapeDataString(($line -split "uri=")[1].Trim())
$uri | Out-File -Encoding Ascii "$env:TEMP\opencode\last_uri.txt" -Force
```

- relay 未连时点 MetaMask 只会进「Continue in MetaMask」fallback 页（无 openRedirect），需 Back 返回重进钱包列表。
- `UriService.openRedirect` 日志在 `reown_appkit-1.9.0/.../url_utils.dart:82`。

## 五、已知坑（实操修过的）

1. **wallet 端 120s 超时**：旧 `test_e2e.js` 120 秒后退出，而 App 之后才点按钮 → 会话丢、请求无人响应、App 卡 loading。已改**常驻**（`E2E_TIMEOUT=0` 为真，用 `parseInt>0` 判定；不设变量 = 永久）。
2. **insufficient funds**：测试地址余额为 0 → 广播失败、钱包进程退出。先给地址打 WLD：`cast send <addr> --value 9000000000000000 --private-key $env:DEPLOYER_PRIVATE_KEY --rpc-url ...`。
3. **签名后没广播/进程死**：广播异常会让进程退出（`e2e.err.log` 有堆栈）。修好资金/参数后重启流程。
4. **App relay 掉线**：`[RelayClient] Connecting…` 反复出现时 App 的 request 根本发不出去（openRedirect 也不打）。重启 App（`am force-stop` + monkey 启动）会自动恢复 session 订阅。
5. **session 密钥在内存**：wallet 进程退出即丢，App 重启也没用——**必须重新配对**（App 断开→重连→新 URI）。
6. **`CanNotLaunchUrl` 异常**：AppKit 尝试 `metamask://` 深链因 MetaMask 未装抛的**无害**异常；session_request 已先 publish。
7. **权限判断**：创建市场页顶部需显示「当前地址已授权 marketCreator」再提交，否则按钮无响应。

## 六、仓库内相关文件

- `scripts/e2e/test_e2e.js` — 自动钱包（pair/approve/sign/broadcast/respond，常驻）
- `scripts/e2e/proxied_ws.cjs` — relay WSS 代理（Bearer auth + EventEmitter/browser 双 API）
- `scripts/e2e/run_e2e.cmd` / `run_wallet.ps1` — 启动器
- `mobile/lib/pages/create_market_page.dart` — 创建市场表单/权限检查（:170、:203）
- `mobile/lib/services/walletconnect_service.dart` / `wc_config.dart` — AppKit 集成、MetaMask customWallet
- `script/GrantMarketCreator.s.sol` + `broadcast/run-latest.json` — marketCreator 授权（已广播）
- `.env` — 部署者/开发者私钥（勿提交，仅 `.env.example`）