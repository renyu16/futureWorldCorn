# Android APK Implementation Plan (Capacitor Wrap)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.
> 前置条件：UI 重构计划（2026-08-12-ui-redesign-plan.md）Task 3-11 已全部完成并合并。本计划在 `rz-20260812-e2e-wallet-flow` 分支上执行。

**Goal:** 将 React 预测市场 web 应用封装为可侧载安装的 Android APK（后续可上架 Google Play）。

**Architecture:** Capacitor 把现有 React + Vite + wagmi/viem + RainbowKit 应用打包进原生 Android WebView；`npm run build` 产出静态资源后 `cap sync` 同步到 `frontend/android/` 原生工程，Gradle 打包签名 APK。钱包经 WalletConnect v2 深链唤起手机钱包。

**Tech Stack:** Capacitor 6/7、Android Gradle Plugin、JDK 21、Android SDK 34/35、`@capacitor/app`。

参考设计：`docs/plans/2026-08-13-android-apk-design.md`

---

### Task 1: 安装 Capacitor 依赖 + vite base 配置

**Files:**
- Modify: `frontend/package.json`
- Modify: `frontend/vite.config.ts`

**Step 1: 安装依赖**

Run: `cd frontend; npm install @capacitor/core @capacitor/cli @capacitor/android @capacitor/app`
Expected: 安装成功，package.json 出现 `@capacitor/*` 依赖

**Step 2: vite.config.ts 加 base**

将 `export default defineConfig({` 改为：

```ts
export default defineConfig({
  base: './',
```

**Step 3: 验证构建**

Run: `cd frontend; npm run build`
Expected: `dist/` 生成，无 TS 错误

**Step 4: Commit**

```bash
git add frontend/package.json frontend/package-lock.json frontend/vite.config.ts
git commit -m "chore: add Capacitor deps and relative base path"
```

---

### Task 2: 初始化 Capacitor 工程

**Files:**
- Create: `frontend/capacitor.config.json`
- Create: `frontend/android/`（cap add 生成）

**Step 1: 写 capacitor.config.json**

```json
{
  "appId": "com.predictionmaster.app",
  "appName": "Prediction Master",
  "webDir": "dist"
}
```

**Step 2: 初始化**

Run: `cd frontend; npx cap init --web-dir dist`
Expected: 输出 "Capacitor project created" 提示（若 config.json 已存在则跳过）

**Step 3: 添加 Android 平台**

Run: `cd frontend; npx cap add android`
Expected: `android/` 目录生成，包含 Gradle 工程

**Step 4: 同步 web 资源**

Run: `cd frontend; npx cap sync android`
Expected: `dist/` 内容复制到 `android/app/src/main/assets/public/`

**Step 5: gitignore android + dist**

在 `frontend/.gitignore`（或仓库根 `.gitignore`）追加：

```
frontend/dist/
frontend/android/
```

**Step 6: Commit**

```bash
git add frontend/capacitor.config.json frontend/.gitignore .gitignore
git commit -m "chore: add Capacitor android project scaffold"
```

---

### Task 3: WalletConnect 深链返回处理

**Files:**
- Create: `frontend/src/capacitor.ts`
- Modify: `frontend/src/main.tsx`

**Step 1: 写 capacitor.ts**

```ts
import { App } from '@capacitor/app'
import type { Capacitor } from '@capacitor/core'

export const isNative = (): boolean =>
  typeof (window as any).Capacitor !== 'undefined' &&
  (window as any).Capacitor.isNativePlatform?.()

export async function setupDeepLink(): Promise<void> {
  if (!isNative()) return
  await App.addListener('appUrlOpen', (data) => {
    const url = data.url
    if (url.startsWith('wc:')) {
      window.location.href = url
    }
  })
}
```

**Step 2: main.tsx 调用**

在 `config` 定义之后、render 之前添加：

```ts
import { setupDeepLink } from './capacitor'
setupDeepLink()
```

**Step 3: 验证构建**

Run: `cd frontend; npx tsc --noEmit`
Expected: 无类型错误（`@capacitor/app` 已安装）

**Step 4: Commit**

```bash
git add frontend/src/capacitor.ts frontend/src/main.tsx
git commit -m "feat: handle WalletConnect deep link return in Capacitor"
```

---

### Task 4: 移动端触控/安全区优化

**Files:**
- Modify: `frontend/src/globals.css`
- Modify: `frontend/index.html`

**Step 1: globals.css 追加触控优化**

```css
html {
  -webkit-tap-highlight-color: transparent;
  -webkit-text-size-adjust: 100%;
}
body {
  padding-top: env(safe-area-inset-top);
  padding-bottom: env(safe-area-inset-bottom);
}
```

**Step 2: index.html viewport-fit**

`<meta name="viewport" ...>` 加 `viewport-fit=cover`：

```html
<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover" />
```

**Step 3: 验证构建**

Run: `cd frontend; npm run build`
Expected: 无错误

**Step 4: Commit**

```bash
git add frontend/src/globals.css frontend/index.html
git commit -m "feat: mobile touch and safe-area optimizations"
```

---

### Task 5: release 签名 keystore + APK 构建

**Files:**
- Create: `frontend/android/keystore.properties`（gitignore，本机安全位置另存一份）
- Modify: `frontend/android/app/build.gradle`（签名配置）
- Modify: `frontend/android/app/build.gradle`（从 keystore.properties 读取）

**Step 1: 生成 keystore**

Run（在 `frontend/android/` 下）:

```powershell
keytool -genkeypair -v -keystore release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias predictionmaster -storepass <STRONG_PASS> -keypass <STRONG_PASS> -dname "CN=Prediction Master, OU=Dev, O=FutureWorldCorn, L=Beijing, C=CN"
```

Expected: `release-key.jks` 生成。**将 keystore + 密码保存到本机安全位置（如 `C:\Users\rztia\AppData\Local\Temp\opencode` 之外的项目外目录），勿入仓库。**

**Step 2: 写 keystore.properties**

```
storeFile=release-key.jks
storePassword=<STRONG_PASS>
keyAlias=predictionmaster
keyPassword=<STRONG_PASS>
```

（文件加入 `.gitignore`，提交时确保不进仓库）

**Step 3: build.gradle 加签名**

`frontend/android/app/build.gradle` 顶部加：

```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file("keystore.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

`android { signingConfigs { release { ... } } }` 配 release 签名，`buildTypes.release` 引用 `signingConfig signingConfigs.release`。

**Step 4: 构建 release APK**

Run: `cd frontend/android; .\gradlew assembleRelease`
Expected: `android/app/build/outputs/apk/release/app-release.apk` 生成

**Step 5: Commit（不含 keystore.properties / release-key.jks）**

```bash
git add frontend/android/app/build.gradle .gitignore
git commit -m "chore: configure release signing for APK"
```

---

### Task 6: 真机/模拟器安装验证

**Files:** 无代码改动（仅验证）

**Step 1: 启动模拟器（如已有运行设备可跳过）**

Run: `$env:ANDROID_HOME\emulator\emulator.exe -list-avds`
Expected: 列出可用 AVD

若存在，启动：

Run: `& "$env:ANDROID_HOME\emulator\emulator.exe" -avd <AVD_NAME>`

**Step 2: 安装 APK**

Run: `& "$env:ANDROID_HOME\platform-tools\adb.exe" install -r frontend/android/app/build/outputs/apk/release/app-release.apk`
Expected: `Success`

**Step 3: 功能冒烟**

- 打开 App，确认 UI 加载正常（无白屏）
- 点击"连接钱包"→ 确认 WalletConnect 面板弹出
- 走通：浏览市场列表 → 打开详情 → 下单 →（钱包深链确认）

**Step 4: 浏览器回归**

Run: `cd frontend; npm run test:ui`
Expected: 16/16 通过

---

### Task 7: 收尾提交

**Step 1: 检查 git status**

Run: `git status`
Expected: 无 `keystore.properties`、`release-key.jks`、`dist/`、`android/` 泄漏（均已 gitignore）

**Step 2: 提交剩余改动**

```bash
git add -A
git commit -m "chore: finalize Android APK build pipeline"
```

**Step 3: 合并回 main（如需）**

```bash
git checkout main && git merge rz-20260812-e2e-wallet-flow && git push
```

---

## 备注

- Google Play 上架（后期）：`bundleRelease` 出 AAB，Play App Signing 上传 key
- 若 `npx cap add android` 需要网络下载 Gradle 依赖，确保网络通畅
- `@capacitor/core` 的 `Capacitor.isNativePlatform()` 在 WebView 下返回 true，浏览器下 false（安全）
