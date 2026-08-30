# AGENTS.md

## 提交与推送约定

- 用户明确要求的提交，或按计划/常规流程需要提交时：直接提交并**立即推送到 `origin/main`**，无需再询问。
- 提交信息保持仓库风格（简单、带类型前缀，如 `feat:` / `docs:` / `fix:`）。
- **不要**把以下内容提交/推送：
  - `frontend/.env` 等真实环境变量（仅提交 `.env.example`）
  - keystore / 私钥 / 密码等密钥
  - `release/` 组装产物、`frontend/dist/`、`node_modules/`
  - `lib/` 下的 submodule 工作目录（chainlink-brownie-contracts 等）
- 推送若遇网络问题，走已配置的本地代理 `http://127.0.0.1:7897`。