# Android APK 设计 - Capacitor 封装

日期: 2026-08-13
分支: rz-20260812-e2e-wallet-flow
前置: 先完成 UI 重构（2026-08-12 计划 Task 3-11），再执行本计划

## 背景

浏览器侧 E2E + Playwright 验证已通过，UI 重构进行中。目标：将现有 React web 应用封装为可侧载的 Android APK，后续上架 Google Play。

## 技术方案（市场反馈对比）

- **Capacitor（选定）**：Ionic 生态，直接包装现有 React 应用为原生 APK，复用全部 Web3 代码（RainbowKit + wagmi + viem + Tailwind + shadcn），移动端经 WalletConnect 深链连接钱包。工作量最小、最稳。
- **React Native (Expo)**：完全重写前端，UI 与合约逻辑重做，工作量 5-10 倍，仅适合原生性能需求极高的场景。
- **TWA**：纯 WebView 壳，需公网域名托管，钱包/深链体验受限。

## 环境（已具备）

- JDK 21（Alibaba Dragonwell），JAVA_HOME 已配置
- ANDROID_HOME = `D:\soft_dev\tools\androidSDK`（platforms 34/35/36、build-tools 34/35、emulator、system-images）
- Node 24 / npm 11

## 架构

```
frontend/（现有 React + Vite + Tailwind/shadcn + wagmi/viem + RainbowKit）
   ├── capacitor.config.json（appId: com.predictionmaster.app, webDir: dist）
   ├── npx cap add android → android/ 原生工程
   ├── npm run build + npx cap sync → 同步 dist 到原生工程
   └── gradlew assembleRelease → 产出 app-release.apk
```

- 新增依赖：`@capacitor/core`、`@capacitor/cli`、`@capacitor/android`、`@capacitor/app`
- `vite.config.ts` 加 `base: './'`（WebView 以 `file://` 加载打包资源，必须相对路径）
- Android 目标：compileSdk/targetSdk 35，minSdk 22（Capacitor 默认，Android 5.1+）
- `android/`、`dist/` 加入 `.gitignore`（由 `cap sync` 再生成）

## 钱包连接与移动端适配

- RainbowKit WalletConnect v2 流程照常工作：从连接面板选 MetaMask/OKX 等，深链唤起手机钱包确认签名；现有 projectId `38cfd0c495d4727d3d7e51ec3824a052` 复用
- `@capacitor/app` 注册 `onResume`/`getLaunchUrl` 处理 `wc:` 回跳，保证 wagmi 拿到确认结果
- RPC 沿用公共 RPC，WebView 默认网络权限，无需额外配置
- UI 触控优化：`-webkit-tap-highlight-color: transparent`、安全区 padding `env(safe-area-inset-*)`、`viewport-fit=cover`

## 构建 / 签名 / 验证

- 签名：`keytool` 生成自签名 release keystore（`release-key.jks`），配置到 Android Gradle 签名；keystore 本机保存，gitignore 保护，不上传仓库
- 流程：
  ```
  cd frontend
  npm run build && npx cap sync android
  cd android && .\gradlew assembleRelease
  ```
  产物：`android/app/build/outputs/apk/release/app-release.apk`
- 验证：`adb install` 到模拟器或真机，走通 连接钱包 → 下单 → 结算 → 领奖 全流程
- 后期 Google Play：产物改 AAB（`bundleRelease`），Play App Signing，复用 upload key

## 可选项（首版不做，YAGNI）

- App 图标/启动屏自定义
- `@capacitor/status-bar` 等原生插件
- 推送通知
