# Polymarket 风格界面渐进优化设计

> 日期：2026-08-14
> 前置条件：UI 重构计划（2026-08-12-ui-redesign-plan.md）已全部完成；Android APK 计划（2026-08-13-android-apk-plan.md）进行中（Task 5-7 未启动）。本设计独立于 APK 分支，可并行/后续执行。
> 范围：仅首页（MarketList）与单市场交易页（MarketDetail）；其他页面（投资组合/委托/治理/争议）不动。

## 目标

在现有浅色 Worldcoin 主题（背景 #fafafa + 品牌蓝 #617bff）基础上，渐进式吸收 Polymarket 的设计语言：

- 首页顶部热点市场横向滚动区（Polymarket 2026 改版核心视觉）
- 市场卡片信息密度升级（概率大字 + 资金池 + 进度条）
- 交易页重做为 Polymarket 下单面板（YES/NO 大 tab + 实时预计获得）

## 技术约束（已确认）

- 链上数据仅有：`marketCount`、`markets(uint256)` tuple（question, outcomeYes, outcomeNo, deadline, status, result, feeBps）、`sharesYes/No`、`claimed`
- **无订单簿、无历史价格走势**，因此不做 Polymarket 的概率走势图与订单簿
- 对赌赔付模型（合约 `claimReward`）：
  - fee = losingPool × feeBps / 10000（默认 feeBps=200，即 2%）
  - reward = userShares × (losingPool − fee) / winningPool + userShares
  - 即：赢家拿回本金 + 按份额瓜分对手方资金池（扣平台费）

## 设计

### 一、首页（MarketList）

**1.1 热门市场横向滚动区（新增）**

- 数据来源：全部市场 tuple 加载完成后，筛 `status === 0`（进行中），按资金池总量 `outcomeYes + outcomeNo` 降序取 Top 5
- 结构：`overflow-x-auto snap-x` 横向滚动，宽卡约 280px（`min-w-[280px] snap-start`）
- 每卡内容：分类 badge、问题（两行截断 `line-clamp-2`）、YES% 大字（`text-4xl font-extrabold`）、资金池总量（CORN）、截止短格式
- 点击卡 → 进入详情页
- Loading：骨架屏 shimmer（复用全局 Skeleton 组件）；无进行中市场则整个区域隐藏

**1.2 市场卡片升级**

- YES% 保持大字（现 text-3xl font-bold）
- 补一行资金池总量展示（现仅 YES/NO 分开展示）
- 进度条加渐变 + 阴影细化
- hover：阴影加深 + `translateY(-2px)` 过渡
- 已结算卡片灰化（opacity 降低 + 状态 badge 突出）

**1.3 分类筛选栏**

- 保持不变（顶部按钮栏：全部 + 6 分类）

### 二、交易页（MarketDetail）

**2.1 概率头部**

- YES% / NO% 两个大数字并排显示，居中概率条（`bg-yes` 宽度 = yesPct），一眼看出当前隐含概率

**2.2 Polymarket 下单面板（新子组件 TradingPanel）**

- 顶部两个大 tab：**YES（绿）/ NO（红）**，选中态高亮，显示对应隐含概率 %
- 金额输入 + **"最大"按钮**（填入当前余额）
- **预计获得实时计算**（对赌公式，输入 X 后实时展示）：
  - 假设结算时己方池 = 当前己方池 + X
  - 预估收益 = X × (对手池 − fee) / (己方池 + X)，fee = 对手池 × feeBps / 10000
  - 显示：预估收益（CORN）、预计回收 = X + 预估收益、隐含赔率 = 1 + 预估收益 / X
- 对赌模型提示文案："赢家按份额瓜分对手方资金池（平台扣 2%），对手盘不足时收益有限"
- 保留现有 approve → bet 流程（allowance 检查）

**2.3 结算 / 领取区**

- 逻辑不动，样式与全局统一

### 三、全局

- 新增 `Skeleton` 骨架屏组件（shimmer 动画）
- 阴影层级细化（card `shadow-sm` → hover `shadow-md`）
- 圆角统一（已定义 radius 0.75rem，继续沿用）

## 测试

- verify-ui.mjs 新增断言：
  1. 热门滚动区渲染（区域存在且卡片数 > 0）
  2. 下单面板存在（YES/NO 两个 tab、金额输入、"最大"按钮、预计获得文本）
  3. 点击"最大"填入金额并显示预计获得
- 原有 17 项保持回归（含分类筛选、角色分权断言）
- `npm run build` 无 TS 错误

## 非目标（YAGNI）

- 不做概率历史走势图、不做订单簿、不做搜索、不做排序切换
- 不改造投资组合/委托/治理/争议页
- 不引入深色主题切换
