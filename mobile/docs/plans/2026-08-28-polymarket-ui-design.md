# Flutter 移动端 Polymarket 风格改造设计

> 日期：2026-08-28
> 前置条件：feature-parity 计划（2026-08-27-complete-feature-parity.md）已完成，5 页面 + 底部导航已就绪。
> 范围：底部导航重构、首页（市场Tab）改版、详情页新增新闻、新增"更多"页面。其他页面（投资/治理）仅调整入口，不重写。

## 目标

参考 https://polymarket.com/ 的移动端信息架构与视觉语言，渐进式改造现有浅色主题 Flutter 应用：

- 底部导航从 5 Tab 重构为 4 Tab（首页 / 投资 / 治理 / 更多）
- 首页升级为 Polymarket 风格：热门市场轮播 + Breaking News + Hot Topics + 市场列表
- 详情页新增"相关新闻"区块（Google News RSS）
- 保留现有浅色主题与 6 分类体系

## 已确认决策

| 决策点 | 选择 |
|--------|------|
| 底部导航 | 首页/投资/治理/更多（委托+争议+设置并入"更多"） |
| 主题 | 保留浅色（不引入深色切换） |
| Breaking News 新闻源 | Google News RSS（免费无限、免Key、支持中文） |
| 分类导航 | 保留 6 类，样式改成 Polymarket 横向分类栏 |
| 概率模拟 | 以链上数据为主，Breaking 概率异动用价格图数据趋势近似 |

## 技术约束

- 链上数据仅有：`marketCount`、`markets(uint256)`、`sharesYes/No`、`claimed`、Event Logs（BetPlaced / VoteCast 等）
- **无新闻 API Key**：Breaking News 使用 Google News RSS（`https://news.google.com/rss/search?q=关键词&hl=zh-CN&gl=CN&ceid=CN:zh-Hans`），Flutter 用 `http` + 轻量 XML 解析（正则/`xml` 包）
- 概率异动无历史 tick 数据，用 `PriceHistoryService`（BetPlaced 事件推导）计算近 N 小时内 YES% 变化幅度，取涨幅榜模拟"概率异动"新闻

## 设计

### 一、底部导航重构（navigation_shell.dart）

```
Tab 1: 首页    (Icons.home)      → HomePage（改版后）
Tab 2: 投资    (Icons.wallet)    → PortfolioPage
Tab 3: 治理    (Icons.how_to_vote) → GovernancePage
Tab 4: 更多    (Icons.more_horiz) → MorePage（新）
```

- `IndexedStack` 保持页面状态
- MorePage 为入口列表卡：委托管理（DelegatePage）、HumanHouse 争议（HumanHousePage）、网络设置（SettingsPage）
- MorePage 内点击进入子页面需在根导航（覆盖底部栏）push 全屏路由

### 二、首页改版（home_page.dart 重构）

页面自上而下区块：

**2.1 热门市场轮播（Featured Carousel）**
- `PageView` 横向滑动，一屏约 1.1 张卡，圆角大卡（佩 Polymarket 卡片风格）
- 数据：`status==0` 市场按资金池 `outcomeYes+outcomeNo` 降序 Top 5
- 卡片内容：分类 badge、问题（2 行截断）、YES% 大字、资金池（CORN）、截止
- 支持手动滑动 + 指标点（page indicator）
- 无进行中市场时隐藏该区块

**2.2 Breaking News 区块**
- 顶部标题栏："Breaking" + 火苗图标（Polymarket 风格）
- 数据源：Google News RSS 搜索关键词（`crypto`、`bitcoin`、`fed`、`以太坊` 等），取最近文章标题、来源、发布时间
- 列表项：标题（1 行截断）+ 来源 · 相对时间
- 加载失败时降级为空态文案（不阻塞主页）
- 拉取缓存 5 分钟（避免频繁请求）

**2.3 Hot Topics 区块**
- 按 `classifyQuestion` 把进行中市场聚合分类，按各分类资金池总和降序排列
- 横向滚动 Chip：分类名 + 资金池量（Polymarket Hot Topics 风格）
- 点击 Chip → 设置该分类筛选

**2.4 搜索栏 + 分类导航**
- 保留现有 `_SearchBar`
- 分类芯片改横向滚动条样式（6 类 + 全部），选中高亮蓝

**2.5 市场列表**
- 保留现有 `_MarketCard` 列表（含资金池、状态、概率条）

### 三、详情页新增新闻区块（market_detail_page.dart）

- 在价格图/时间线之间插入"相关新闻"折叠区（Collapsible）
- 关键词：市场问题分词 + 分类名（crypto/sports/politics...）拼成 RSS 搜索词
- 点击新闻项可展开简介或外链提示（SnackBar 提示无法内联打开浏览器则复制链接）
- 加载失败隐藏新区块，不影响原功能

### 四、视觉微调（app_theme.dart）

- 概率相关组件统一：YES 绿 `#16A34A`、NO 红 `#DC2626`、主蓝 `#617BFF`（保持不变）
- 轮播卡 / 新闻卡圆角 16，卡片阴影轻微加深，信息密度提升

### 五、新增 / 修改文件

| 文件 | 动作 | 说明 |
|------|------|------|
| `lib/services/news_service.dart` | 新增 | Google News RSS 拉取+解析，返回 `NewsItem` |
| `lib/pages/more_page.dart` | 新增 | "更多"入口列表页 |
| `lib/pages/home_page.dart` | 重构 | 轮播 + Breaking + Hot Topics + 列表 |
| `lib/pages/navigation_shell.dart` | 修改 | 4 Tab + MorePage |
| `lib/pages/market_detail_page.dart` | 修改 | 插入相关新闻区块 |
| `lib/theme/app_theme.dart` | 微调 | 新卡片圆角/阴影 |
| `pubspec.yaml` | 修改 | 新增 `xml` 依赖（RSS 解析） |
| `integration_test/app_test.dart` | 修改 | 更新导航断言（4 Tab）+ 轮播/新闻断言 |

## 测试

- `flutter analyze` 0 error
- 更新集成测试：
  1. 底部导航 4 Tab 断言（首页/投资/治理/更多）
  2. 首页轮播存在（PageView 渲染）
  3. 首页分类导航滚动存在
  4. "更多"页面入口列表渲染（委托/争议/设置）
  5. Breaking News 区块出现（或网络失败时空态）
- 回归原有用例（市场列表、详情页跳转、设置页）

## 非目标（YAGNI）

- 不做深色主题
- 不做订单簿 / 深度图
- 不做新闻详情内联 WebView（外链复制/提示即可）
- 不合并 6 分类为 3 分类
- 不改投资/治理页内部结构