# 正式环境部署（IP+端口静态站 + Android release）Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 本地构建并组装「预测大师」正式测试交付包：Web 前端生产构建 + 零依赖 Node 静态服务 + Android release APK，供用户拷贝到 Alibaba Cloud Linux 服务器以 `http://IP:8085` 访问。

**Architecture:** 前端为纯静态 SPA（Vite，`base: './'`），无需后端。交付包内自带 `serve.mjs`（Node>=18 内置 `http`，零 npm 依赖）做静态服务器，含 SPA 路由回退与正确 MIME。静态服务脚本作为源码保存在 `deploy/webserver/` 以便版本维护；`release/<日期>/` 为组装产物（加入 .gitignore）。

**Tech Stack:** Vite/React（已有）、Node 内置 `http`、Flutter (`flutter build apk --release`)、bash（RHEL 系目标机脚本）。

---

### Task 1: 构建前端生产产物

**Files:**
- Output: `frontend/dist/`（`npm run build` 生成）

**Step 1: 执行构建**

Run:
```powershell
npm run build
```
（在 `D:\soft_dev\workspace\go\futureWorldCorn\frontend`）

**Step 2: 验证产物**

Run:
```powershell
Test-Path frontend/dist/index.html; Get-ChildItem frontend/dist/assets | Select-Object Name, Length
```
Expected: `index.html` 存在，`assets/` 下有 hash 命名的 `.js`/`.css`。

**Step 3: 记录产物信息**

确认 `frontend/dist/index.html` 中引用的资源路径为相对路径（`./assets/...`，因 `base: './'`），若出现绝对 `/assets/...` 需排查。

---

### Task 2: 编写静态服务器与部署脚本

**Files:**
- Create: `deploy/webserver/serve.mjs`
- Create: `deploy/webserver/start.sh`
- Create: `deploy/webserver/stop.sh`
- Create: `deploy/webserver/install-node.sh`

**Step 1: 创建 `serve.mjs`**

```js
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const DEFAULT_PORT = 8085;
const DEFAULT_DIR = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'web');

function parseArgs(argv) {
  const args = { port: DEFAULT_PORT, host: '0.0.0.0', dir: DEFAULT_DIR };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--port') args.port = Number(argv[++i]);
    else if (argv[i] === '--host') args.host = argv[++i];
    else if (argv[i] === '--dir') args.dir = argv[++i];
  }
  return args;
}

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.txt': 'text/plain; charset=utf-8',
  '.map': 'application/json; charset=utf-8',
};

const args = parseArgs(process.argv.slice(2));
const root = path.resolve(args.dir);
const port = args.port;
const host = args.host;

function send(res, status, chunk, headers = {}) {
  const len = typeof chunk === 'string' ? Buffer.byteLength(chunk) : chunk.length;
  res.writeHead(status, { 'Content-Length': len, ...headers });
  res.end(chunk);
}

function serveFile(res, filePath) {
  fs.readFile(filePath, (err, buf) => {
    if (err) return send(res, 404, 'Not Found');
    const ext = path.extname(filePath).toLowerCase();
    send(res, 200, buf, { 'Content-Type': MIME[ext] || 'application/octet-stream' });
  });
}

const server = http.createServer((req, res) => {
  let urlPath;
  try {
    urlPath = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
  } catch {
    return send(res, 400, 'Bad Request');
  }
  let filePath = path.join(root, urlPath === '/' ? 'index.html' : urlPath);
  if (!filePath.startsWith(root)) return send(res, 403, 'Forbidden');
  if (fs.existsSync(filePath) && fs.statSync(filePath).isDirectory()) {
    filePath = path.join(filePath, 'index.html');
  }
  if (fs.existsSync(filePath)) return serveFile(res, filePath);
  if (!path.extname(urlPath)) return serveFile(res, path.join(root, 'index.html'));
  send(res, 404, 'Not Found');
});

server.listen(port, host, () => {
  console.log(`serving ${root} on http://${host}:${port}`);
});
```

**Step 2: 创建 `start.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

PORT="${PORT:-8085}"
WEB_DIR="${WEB_DIR:-$(cd "$(dirname "$0")/../web" && pwd)}"

if [[ ! -f "$WEB_DIR/index.html" ]]; then
  echo "error: web bundle not found at $WEB_DIR (run npm run build and assemble package first)" >&2
  exit 1
fi

if command -v node >/dev/null 2>&1; then
  NODE_MAJOR="$(node -v | sed 's/v//; s/\..*//')"
  if [[ "$NODE_MAJOR" -lt 18 ]]; then
    echo "error: node >= 18 required, found $(node -v) (run ./install-node.sh)" >&2
    exit 1
  fi
else
  echo "error: node not found (run ./install-node.sh)" >&2
  exit 1
fi

if [[ -f .pid ]] && kill -0 "$(cat .pid)" 2>/dev/null; then
  echo "already running with pid $(cat .pid)"
  exit 0
fi

nohup node serve.mjs --port "$PORT" --host 0.0.0.0 --dir "$WEB_DIR" > server.log 2>&1 &
echo $! > .pid
sleep 1
if kill -0 "$(cat .pid)" 2>/dev/null; then
  echo "started on port $PORT (pid $(cat .pid)) — see server.log"
else
  echo "failed to start; see server.log" >&2
  exit 1
fi
```

**Step 3: 创建 `stop.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ -f .pid ]] && kill -0 "$(cat .pid)" 2>/dev/null; then
  kill "$(cat .pid)"
  rm -f .pid
  echo "stopped"
else
  echo "not running"
fi
```

**Step 4: 创建 `install-node.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

if command -v node >/dev/null 2>&1; then
  MAJOR="$(node -v | sed 's/v//; s/\..*//')"
  if [[ "$MAJOR" -ge 18 ]]; then
    echo "node already installed: $(node -v)"
    exit 0
  fi
  echo "node too old: $(node -v), installing NodeSource 20..."
else
  echo "installing NodeSource 20..."
fi

if command -v dnf >/dev/null 2>&1; then
  (curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -) && dnf -y install nodejs
else
  echo "error: unsupported package manager (only RHEL-family with dnf supported)" >&2
  exit 1
fi

hash -r
node -v
```

**Step 5: 赋可执行权限**

Run: `git update-index --chmod=+x deploy/webserver/*.sh` 或在 git 提交时配置 `core.filemode` 前手动 `chmod +x`（Windows 上 git 会记录为文件模式变更，提交后目标机直接可用）。

---

### Task 3: 本地冒烟测试静态服务器

**Files:**
- Test: `frontend/dist/`（用 Task 1 产物）

**Step 1: 启动服务**

Run:
```powershell
node deploy/webserver/serve.mjs --port 8099 --dir frontend/dist
```
（本地用 8099 避免与 8085 冲突，起另一个终端执行下面 curl）

**Step 2: curl 冒烟**

Run:
```powershell
curl -s -o NUL -w "%{http_code} %{content_type}%n" http://127.0.0.1:8099/
curl -s -o NUL -w "%{http_code} %{content_type}%n" http://127.0.0.1:8099/portfolio
curl -s -o NUL -w "%{http_code} %{content_type}%n" http://127.0.0.1:8099/assets/(从 index.html 解析出的主 js 文件名)
curl -s -o NUL -w "%{http_code}%n" http://127.0.0.1:8099/nonexistent.js
```

Expected:
- `/` → `200 text/html`
- `/portfolio`（SPA 深链）→ `200 text/html`（回退 index.html）
- 主 JS 资源 → `200 text/javascript`
- `/nonexistent.js`（带扩展名、非回退）→ `404`

**Step 3: 停止测试服务**

Run: 对 `serve.mjs` 进程 Ctrl+C。

---

### Task 4: 构建 Android release APK

**Files:**
- Output: `mobile/build/app/outputs/flutter-apk/app-release.apk`

**Step 1: 构建**

Run（在 `D:\soft_dev\workspace\go\futureWorldCorn\mobile`）:
```powershell
& "C:\tools\flutter\bin\flutter.bat" build apk --release
```
Expected: `Building with sound null safety`，末尾 `√ Built build\app\outputs\flutter-apk\app-release.apk`

**Step 2: 记录 APK 大小与版本**

Run:
```powershell
Get-Item mobile/build/app/outputs/flutter-apk/app-release.apk | Select-Object Name, Length
```
Expected: 文件存在，大小 MB 级。版本取自 `mobile/pubspec.yaml` `version: x.y.z+n`。

---

### Task 5: 组装 release 交付包

**Files:**
- Create: `release/<YYYY-MM-DD>/web/`（dist 拷贝）
- Create: `release/<YYYY-MM-DD>/server/`（deploy/webserver 四文件拷贝）
- Create: `release/<YYYY-MM-DD>/android/app-release.apk`
- Create: `release/<YYYY-MM-DD>/README.md`
- Modify: `.gitignore`（追加 `release/`）

**Step 1: 更新 `.gitignore`**

追加：
```
# 部署交付包（组装产物）
release/
```

**Step 2: 组装目录**

Run（日期以当天 `2026-08-28` 为例）:
```powershell
$d = Get-Date -Format "yyyy-MM-dd"
New-Item -ItemType Directory -Force -Path "release/$d/web"
Copy-Item frontend/dist/* "release/$d/web/" -Recurse
New-Item -ItemType Directory -Force -Path "release/$d/server"
Copy-Item deploy/webserver/* "release/$d/server/"
Copy-Item mobile/build/app/outputs/flutter-apk/app-release.apk "release/$d/android/app-release.apk"
```

**Step 3: 编写 `release/<d>/README.md`**

内容要点（面向 RHEL 系目标机）：
- 环境要求：Node>=18、bash、端口 8085
- 部署：`scp`/拷入 `release/<d>/` → `cd server` → `./install-node.sh`（缺 Node 时）→ `./start.sh`
- 放行端口：`firewall-cmd --permanent --add-port=8085/tcp && firewall-cmd --reload`（如启用 firewalld）+ 阿里云安全组入方向放行 8085
- 运维：`./stop.sh`、日志 `server.log`
- APK：`android/app-release.apk` 安装到 Android 设备（当前为默认 debug 签名，上架签名后续）
- 备注：本次为 IP+HTTP；域名就绪后迁移 nginx+HTTPS

**Step 4: 验证包结构**

Run:
```powershell
Get-ChildItem -Recurse "release/$d" | Select-Object FullName, Length
```
Expected: `web/index.html`、`web/assets/*`、`server/{serve.mjs,start.sh,stop.sh,install-node.sh}`、`android/app-release.apk`、`README.md` 齐全。

---

### Task 6: 交付包整体冒烟

**Files:**
- Test: `release/<d>/web/`

**Step 1: 用交付包内脚本路径启动**

Run:
```powershell
node release/<d>/server/serve.mjs --port 8098 --dir release/<d>/web
```
curl 复测 Task 3 四个用例（`/`、SPA 深链、asset mime、404），Expected 同上。

**Step 2: APK 模拟器冒烟**

Run:
```powershell
& "D:\soft_dev\tools\androidSDK\platform-tools\adb.exe" install -r "release/<d>/android/app-release.apk"
& "C:\tools\flutter\bin\flutter.bat" test integration_test\app_test.dart -d emulator-5554
```
（可选，若 simulate release 构建行为；至少验证 release APK 可安装启动）

---

### Task 7: 提交

**Step 1: 暂存与提交**

Run:
```powershell
git add .gitignore deploy/
git commit -m "feat: add production static web server scripts and deploy package assembly; ignore release artifacts"
```
（`release/` 已被 .gitignore 排除，不入库）

**Step 2: 推送（如网络可用）**

Run: `git push -u origin main`

---

## 验收清单

- [ ] `frontend/dist/index.html` 相对路径引用资源
- [ ] `serve.mjs` 冒烟四用例全部符合预期
- [ ] `app-release.apk` 构建成功且可安装
- [ ] `release/<d>/` 结构完整、README 正确
- [ ] 交付包整体冒烟通过
- [ ] `deploy/` 已提交，`release/` 已忽略