# 正式环境部署设计（IP+端口、Alibaba Cloud Linux）

日期: 2026-08-28

## 目标

将「预测大师」部署到用户自有的 Linux 服务器（正式环境测试），交付：

1. **Web 前端** —— 构建产物 + 零依赖 Node 静态服务器，`http://IP:8085` 访问
2. **Android release APK** —— 可安装的正式测试版

## 环境

| 项 | 值 |
|---|---|
| 服务器 | Alibaba Cloud Linux 3.2104（OpenAnolis 版，RHEL 系，x86_64） |
| 访问方式 | 根 shell（root），SSH 凭据待提供 |
| 暴露方式 | IP + HTTP，端口 `8085`（暂不装 nginx；域名就绪后换 nginx+HTTPS） |
| 前端架构 | 纯静态 SPA（`base: './'`），直连 World Chain Sepolia (4801)，无后端 |

## 交付包结构 `release/<日期>/`

| 路径 | 说明 |
|---|---|
| `web/` | `npm run build` 产物（dist 内容展开） |
| `server/serve.mjs` | Node 内置 `http` 静态服务器（Node>=18 零依赖）：端口 8085、SPA 路由回退 `index.html`、正确 content-type、目录索引 `index.html` |
| `server/start.sh` | 后台启动（`nohup` + PID 文件 + 状态提示）；无 Node 则给出安装指引 |
| `server/stop.sh` | 按 PID 停止 |
| `server/install-node.sh` | RHEL 系安装 Node>=18（优先 dnf 现有版本，否则 NodeSource） |
| `android/app-release.apk` | `flutter build apk --release`（当前用模板默认签名，测试安装用；上架签名后续处理） |
| `README.md` | 部署说明 + 安全组/防火墙放行 8085 |

## serve.mjs 行为

- `--port` 默认 `8085`，`--dir` 默认同目录 `../web`，`--host` 默认 `0.0.0.0`
- 静态文件 + 正确 Content-Type 映射（html/js/css/json/svg/png/ico/font）
- 不存在路径回退 `index.html`（SPA 深链刷新不 404）
- 404（index.html 也不存在时）、带 `Content-Length`/`Cache-Control` 头

## 目标机上线流程

1. `install-node.sh`（缺 Node 时）或系统已有 Node>=18
2. `scp`/拷入整个 `release/<日期>/` 目录
3. `cd server && ./start.sh`（写 PID 到 `server/.pid`）
4. 开放 `8085`：`firewall-cmd --add-port=8085/tcp --permanent && firewall-cmd --reload`（如有 firewalld）+ 阿里云安全组放行
5. 浏览器访问 `http://IP:8085`

## 本地验证

- 本机 `node server/serve.mjs` 起服务后 curl 冒烟：
  - `/` 返回 200 且为 HTML
  - `/portfolio` 等 SPA 深链回退 200（返回 index.html）
  - `/assets/*.js` 200 且 `Content-Type: text/javascript`
- release APK 安装到模拟器冒烟启动

## 后续（不在本次范围）

- 域名就绪后：nginx + HTTPS + 端口收敛为 80/443
- APK 正式签名与分发（商店/分发渠道）