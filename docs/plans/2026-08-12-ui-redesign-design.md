# UI 重构设计 - shadcn/ui + Tailwind（浅色 Worldcoin 风）

日期: 2026-08-12
分支: rz-20260812-e2e-wallet-flow

## 背景

当前前端所有页面使用内联 `style={{...}}`，无设计系统，视觉粗糙。E2E 验证已确认功能正确，现统一重构为现代浅色风格。

## 技术栈

- **Tailwind CSS v4**（`@tailwindcss/vite` 插件，CSS-first，零配置文件）
- **shadcn/ui**（Radix UI + CVA，组件源码 copy 到 `src/components/ui/`，非 npm 黑盒）
- **lucide-react**（图标）
- **clsx + tailwind-merge**（`cn()` 工具）
- **class-variance-authority**（组件变体）

## 目录结构（新增）

```
frontend/src/
  components/
    ui/              # shadcn 组件源码（button/card/input/badge/tabs/dialog/select 等）
    WalletConnect.tsx  # 已有，保留
  lib/
    utils.ts         # cn() 工具函数
  globals.css        # Tailwind 指令 + design tokens
```

移除所有内联 `style={{...}}`，全部换 Tailwind class。

## 设计 Token（浅色 Worldcoin 风）

- 背景：`#fafafa` / 卡片 `#ffffff`
- 主色：`#617bff`（Worldcoin 蓝）
- YES 绿 `#16a34a` / NO 红 `#dc2626`
- 文字：主 `#0a0a0a` / 次 `#737373`
- 圆角：`0.75rem`，边框 `#e5e5e5`

## 布局

顶部 sticky header（logo + 横向 Tabs 导航 + 右侧 ConnectButton），主区域 max-width 居中。

## 组件映射（7 页面）

- **Markets 列表**：响应式网格，Card 卡片（Badge 状态色 / YES-NO pool 进度条 / 截止时间）
- **MarketDetail**：Card + 分区（信息 / 下注表单 / resolve / claim），Input + Select + Button
- **Create**：Card 包裹表单，Input + datetime-local + Button
- **Portfolio**：未连接空状态 Card；连接后余额卡 + 持仓列表
- **Delegate**：3 个 Card（余额 / 存取 / 委托），Approve->Deposit 两步按钮
- **Governance / Disputes**：列表 + 详情用 Card，创建用 Dialog 弹窗

## 状态色

Open 蓝 / Resolved 绿 / Cancelled 灰；YES 绿 NO 红。

## 可访问性

Radix 组件自带键盘/焦点支持；所有交互按钮有 loading/disabled 态。

## 验收标准

- `npm run build` 通过
- `npm run test:ui` 16 项全绿
- 手动浏览各页面视觉统一、无内联 style 残留
