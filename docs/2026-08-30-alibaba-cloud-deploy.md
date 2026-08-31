# 阿里云服务器部署指南 — 预测大师 Web + Android

> 适用范围：把前端静态站点与 Android APK 部署到阿里云 ECS（Alibaba Cloud Linux 3，RHEL8/9 系）。
> 本指南针对 `release/<日期>/` 交付包（组装产物，不入 git）。合约部署见根目录 [DEPLOY.md](../../DEPLOY.md)。

## 1. 交付包结构

```
release/<YYYY-MM-DD>/
├── README.md              # 面向目标机的简版说明
├── web/                   # 前端静态产物（Vite build，base './'，纯静态无后端）
├── server/                # 静态服务器脚本（Node>=18 内置 http，零 npm 依赖）
│   ├── serve.mjs          # 静态服务器：SPA 回退 + 正确 MIME + 路径安全 + POST /rpc JSON-RPC 反代
│   ├── start.sh           # 启动（默认端口 8085，日志 server.log，写 .pid）
│   ├── stop.sh            # 停止（带进程身份校验，清理陈旧 .pid）
│   └── install-node.sh    # 安装 Node 18+（需 root；已装则跳过）
└── android/
    └── app-release.apk    # Flutter release 构建（模板默认签名，测试安装用）
```

## 2. 安全准则：最小暴露（Least Privilege）

本项目安全立场：**不必要不暴露，需要才暴露**（与 Polymarket 等"全公开"路线区分，见 [架构对比](./2026-08-30-architecture-vs-polymarket.md)）。

- **公网只开业务必需端口**（默认 `8085`），其它端口一律不开放
- **安全组默认拒绝、最小放行**：只放行业务所需来源；内测期收窄为运维 / 测试公网 IP 白名单，正式公开运营前不写 `0.0.0.0/0`
- **SSH(22) 仅对运维 IP 放行**、仅密钥登录，不用密码
- **不与业务无关的软件不装**；示例 `.env` 中未启用的配置项不开启，避免引入不必要面
- **链上权限与 Web 服务器分离**：keeper / resolveMarket / 治理角色密钥不部署到对外服务的机器
- **构建产物不公开**：`release/`、`frontend/dist/`、`.env` 均不入库

## 3. 前置条件

- 阿里云 ECS，Alibaba Cloud Linux 3（自带 `dnf`），有 `root` 或 `sudo`
- 端口：目标 **8085/tcp**（可改，见 [9. 运维](#9-运维)）
- 服务器无需 Node 预装（`install-node.sh` 自动安装），无需 npm 依赖
- 本地开发机有能与目标机互通的网络

## 4. 本地：构建与组装交付包

> 使用已交付的 `release/<日期>/` 可直接跳到 [5. 上传](#5-上传)。下面用于重新打包。

```powershell
# 前端（代码有变动时）
cd frontend
npm install
# 部署在阿里云时 RPC 走服务器反代（手机网络直连 alchemy 可能失败）：
$env:VITE_RPC_URL = "http://8.141.100.69:8085/rpc"
npm run build            # 产物输出到 frontend/dist

# Android APK（可选，代码有变动时）
cd ../mobile
flutter build apk --release   # 产物 mobile/build/app/outputs/flutter-apk/app-release.apk
```

组装（日期以 `$d` 变量传入）：

```powershell
$d = Get-Date -Format "yyyy-MM-dd"
New-Item -ItemType Directory -Force -Path "release/$d/web"
Copy-Item frontend/dist/* "release/$d/web/" -Recurse
New-Item -ItemType Directory -Force -Path "release/$d/server"
Copy-Item deploy/webserver/* "release/$d/server/"
New-Item -ItemType Directory -Force -Path "release/$d/android"
Copy-Item mobile/build/app/outputs/flutter-apk/app-release.apk "release/$d/android/app-release.apk"
Get-ChildItem -Recurse "release/$d" | Select-Object FullName, Length
```

## 5. 上传交付包

本地开发机执行（Windows PowerShell）：

```powershell
scp -r ./release/2026-08-30 <user>@<server-ip>:~/
```

## 6. 服务器部署

```bash
ssh <user>@<server-ip>
cd ~/2026-08-30/server
```

### 6.1 安装 Node（缺少或 <18 时）

```bash
sudo ./install-node.sh
node -v        # 期望 v18+
```

> 脚本优先使用 `dnf module` 安装 nodejs:20，失败时回退 NodeSource 20；root 运行。

### 6.2 启动服务

```bash
./start.sh
# ok
```

- 默认监听 `0.0.0.0:8085`，日志写入 `server.log`，PID 记入 `.pid`
- 指定端口：`./start.sh 9080`

**本机自检：**

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8085/
# 200
```

### 6.3 放行 8085

```bash
sudo firewall-cmd --permanent --add-port=8085/tcp
sudo firewall-cmd --reload
sudo firewall-cmd --list-ports    # 确认 8085/tcp
```

## 7. 阿里云安全组放行（默认拒绝 + 最小放行）

> 原则见 [2. 安全准则](#2-安全准则最小暴露least-privilege)：默认拒绝，需要才放行。

1. 登录阿里云控制台 → ECS → 实例 → 该实例 → **安全组**
2. 确认当前策略为**默认拒绝**（未放行的端口不可入站）；在已有规则基础上逐条最小放行，不叠加无关端口
3. 入方向 → 手动添加规则（按需最小化）：
   | 用途 | 协议 | 端口 | 授权对象（最小化） |
   |------|------|------|---------------------|
   | 业务入口（必备） | TCP | **8085** | 内测期：运维/测试公网 IP 段；正式公开运营才改为 `0.0.0.0/0` |
   | SSH 运维（收敛） | TCP | 22 | 仅运维公网 IP；优先改端口 + 密钥登录 |
   | HTTPS（后续） | TCP | 443 | 仅域名解析目标；届时 8085 可改为仅内网 |
4. 保存后约 1 分钟生效

> 最小暴露提醒：**不要**一次性放行 `0.0.0.0/0` 的 8085，除非明确进入公开运营；未使用端口（8545 等）不放行。

## 8. 验证

### 7.1 公网冒烟（浏览器 / curl）

| 用例 | 命令 | 期望 |
|------|------|------|
| 首页 | `curl http://<server-ip>:8085/` | 200 text/html |
| SPA 深链 | `curl http://<server-ip>:8085/portfolio` | 200 text/html（返回 index.html）|
| 静态资源 | 打开页面按 F12 看 assets | 200 text/javascript / text/css |
| 不存在路径 | `curl http://<server-ip>:8085/no.js` | 404 |

浏览器打开 `http://<server-ip>:8085/`：

1. 连接钱包（WalletConnect / 浏览器扩展）下单测试页面
2. 进入 Market / Portfolio 深链刷新，确认 SPA 回退正常

### 7.2 Android APK

```powershell
# 本地调试机
adb install -r app-release.apk
```

或把 APK 发给设备直接安装。钱包走 WalletConnect，与网页共用一套。

## 9. 运维

```bash
cd ~/2026-08-30/server

./stop.sh        # 停止（自动清理陈旧 .pid）
./start.sh       # 重启（等价 stop + start）
./start.sh 9080  # 换端口启动
tail -f server.log
```

**升级前端**：本地重新 `npm run build` → 用新 `web/` 整目录替换旧 `web/` → `./stop.sh && ./start.sh`（无需重装 Node）。

## 10. 修改链 / 合约地址 / RPC（测试网 ↔ 主网）

前端为纯静态站点，链、RPC、WalletConnect、合约地址均为**构建时配置**（源码集中在 `frontend/src/config.ts`，可用 `frontend/.env` 覆盖）。切换需改配置 → 重新构建 → 替换部署目录 `web/`。

### 9.1 配置项一览

```bash
cd frontend
cp .env.example .env   # 首次使用时复制模板，之后直接编辑 .env
```

| 变量 | 当前值（GET） | 说明 |
|------|---------------|------|
| `VITE_CHAIN_ID` | `4801`（测试网）/ `480`（主网） | 目标链切换开关 |
| `VITE_RPC_URL` | 缺省按链用 Alchemy 公网 | 自有节点可覆盖 |
| `VITE_EXPLORER_URL` | 缺省按链映射 | 区块浏览器 |
| `VITE_PROJECT_ID` | 内置开发用 ID | 需自行注册：[cloud.walletconnect.com](https://cloud.walletconnect.com)（免费） |
| `VITE_CORN_TOKEN_ADDRESS` | 见 config.ts 内置表 | 合约地址覆盖（可选）|
| `VITE_PREDICTION_MARKET_ADDRESS` | 同上 | 同上 |
| `VITE_ORACLE_ADAPTER_ADDRESS` | 同上 | 同上 |
| `VITE_GOV_CORN_TOKEN_ADDRESS` | 同上 | 同上 |
| `VITE_TOKEN_HOUSE_ADDRESS` | 同上 | 同上 |
| `VITE_HUMAN_HOUSE_ADDRESS` | 同上 | 同上 |

### 9.2 正式上线（480 主网）步骤

1. `frontend/.env` 设 `VITE_CHAIN_ID=480`
2. 填入 6 个合约地址（来自 `forge script` 部署输出，**无需注册**）：`CornToken`、`PredictionMarket`(proxy)、`OracleAdapter`、`GovCornToken`、`TokenHouse`、`HumanHouse`
3. 需要时覆盖 RPC / Explorer / ProjectID（ProjectID 需去 WalletConnect Cloud 注册）
4. 重新构建：
   ```bash
   cd frontend
   npm run build
   ```
5. 用新 `frontend/dist/` 整目录替换服务器 `web/`，重启：
   ```bash
   cd ~/<日期>/server
   ./stop.sh && ./start.sh
   ```
6. 重新冒烟（见 [8. 验证](#8-验证））。

> 测试网 4801 地址已内置可直接用；灰度可先保持 4801 验证，再切 480。

### 9.3 JSON-RPC 反代 `/rpc`（手机网络直连 Alchemy 失败的解法）

**现象**：手机（内地网络，无 VPN）上 APK 或网页报 `Failed host lookup: 'worldchain-sepolia.g.alchemy.com' (errno=7)` / 数据加载失败。根因是本地网络 DNS 解析/访问不了 alchemy.com；纯 IP 的 `8.141.100.69:8085` 则完全可达。

**方案**：`serve.mjs` 内置 `POST /rpc` 反向代理，转发到上游节点（默认 `https://worldchain-sepolia.g.alchemy.com/public`，可用环境变量 `RPC_PROXY_UPSTREAM` 覆盖，如后续切主网 `RPC_PROXY_UPSTREAM=https://worldchain-mainnet.g.alchemy.com/public`）。手机只访问服务器 IP，不再依赖 alchemy.com 的 DNS。

- 用法示例：`curl -X POST http://8.141.100.69:8085/rpc -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'`
- web 端：构建时 `VITE_RPC_URL=http://8.141.100.69:8085/rpc`（本仓库交付包默认已如此构建）；也可不重新构建，在页面「设置 → RPC 节点」填入该地址（存 localStorage）
- APK 端：交付包 APK 默认已指向该地址；老 APK 可在「更多 → 设置」里填 RPC 后保存
- 反代为只读转发，避免引入额外暴露面；非 JSON-RPC 的 `/rpc` 请求返回 405

## 11. HTTPS / 域名迁移（后续）

当前为 **IP + HTTP(8085)**。域名与证书就绪后：

1. 域名 A 记录指向服务器公网 IP
2. 装 nginx：`sudo dnf install -y nginx`
3. nginx 配置 `server_name <域名>`，443 反代/静态指向 `~/2026-08-30/web`（SPA 需 `try_files $uri /index.html;`）
4. certbot 自动续期证书；安全组放行 443；8085 可关闭或仅内网

## 12. 故障排查

| 现象 | 排查 |
|------|------|
| 外网打不开，本机 200 | 安全组未放行 8085（见 [7](#7-阿里云安全组放行控制台)）；`firewall-cmd --list-ports` 确认 |
| `start.sh` 报地址占用 | `ss -tlnp | grep 8085` 查占用；`stop.sh` 清理后重启，或换端口 |
| 深链刷新 404 | 确认用的是 `web/` 且启动参数 `--dir` 指向它；旧 serve 进程未停会占 8085 |
| `install-node.sh` 失败 | 需 root；curl 可用；dnf 源可达（`dnf makecache`）|
| 页面 JS 报跨域/白屏 | 打开 F12 Network，确认资源 200 且相对路径（以 `./` 开头），无 CDN 硬地址 |
| APK/页面报 `Failed host lookup ... alchemy.com` | 网络 DNS 解析不了 alchemy，改用反代 `http://8.141.100.69:8085/rpc`（见 [9.3](#93-json-rpc-反代-rpc手机网络直连-alchemy-失败的解法)）|
| 重启后自动失效 | 当前为前台启动方案；如需开机自启，可加 systemd unit 或 init 脚本（后续可提供） |