# Flutter Polymarket 风格改造实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 Flutter 移动端重构为 Polymarket 风格信息架构（4 Tab 导航 + 首页轮播/Breaking/Hot Topics + 详情页新闻）。

**Architecture:** 底部导航 5 Tab → 4 Tab（首页/投资/治理/更多），委托+争议+设置并入"更多"入口页；首页重构为轮播 + Google News RSS Breaking News + 分类资金池 Hot Topics + 市场列表；详情页插入相关新闻区。保留浅色主题与 6 分类。

**Tech Stack:** Flutter 3.41 / Dart 3.11, flutter_riverpod 2.6.1, http 1.2.2, xml（新增 RSS 解析）, integration_test

---

### Task 1: 添加 xml 依赖 + 创建 NewsService

**Files:**
- Modify: `pubspec.yaml`（dev 之外的 dependencies 加 `xml: ^6.5.0`）
- Create: `lib/services/news_service.dart`
- Create: `test/news_service_test.dart`

**Step 1: 修改 pubspec.yaml**

在 `dependencies:` 中 `shared_preferences` 之后添加：
```yaml
  xml: ^6.5.0
```

**Step 2: 写 NewsService（先写实现，RSS 解析用 XML 解析）**

```dart
// lib/services/news_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

class NewsItem {
  final String title;
  final String source;
  final String link;
  final DateTime published;
  const NewsItem({required this.title, required this.source, required this.link, required this.published});
}

class NewsService {
  static const _cacheDuration = Duration(minutes: 5);
  static Map<String, (List<NewsItem>, DateTime)> _cache = {};

  static List<String> defaultKeywords = ['crypto', '比特币', '以太坊', '美联储', 'fed'];

  static Future<List<NewsItem>> fetch(List<String> keywords) async {
    final key = keywords.join(',');
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.$2) < _cacheDuration) {
      return cached.$1;
    }
    final results = <NewsItem>[];
    for (final kw in keywords) {
      try {
        final uri = Uri.parse(
            'https://news.google.com/rss/search?q=${Uri.encodeQueryComponent(kw)}&hl=zh-CN&gl=CN&ceid=CN:zh-Hans');
        final res = await http.get(uri).timeout(const Duration(seconds: 10));
        if (res.statusCode != 200) continue;
        results.addAll(_parseRss(res.body));
      } catch (_) {}
    }
    // 去重 + 按时间排序 + 截断 20 条
    final seen = <String>{};
    final unique = <NewsItem>[];
    for (final n in results) {
      if (seen.add(n.title)) unique.add(n);
    }
    unique.sort((a, b) => b.published.compareTo(a.published));
    final top = unique.length > 20 ? unique.sublist(0, 20) : unique;
    _cache[key] = (top, DateTime.now());
    return top;
  }

  static List<NewsItem> _parseRss(String body) {
    final items = <NewsItem>[];
    try {
      final doc = XmlDocument.parse(body);
      for (final item in doc.findAllElements('item')) {
        final title = item.findElements('title').firstOrNull?.innerText ?? '';
        final link = item.findElements('link').firstOrNull?.innerText ?? '';
        final pubStr = item.findElements('pubDate').firstOrNull?.innerText ?? '';
        final source = item.findElements('source').firstOrNull?.innerText ?? '新闻';
        DateTime? published;
        try { published = DateTime.parse(pubStr); } catch (_) {}
        if (title.isEmpty) continue;
        items.add(NewsItem(
          title: title.replaceAll(RegExp(r'<[^>]+>'), ''),
          source: source,
          link: link,
          published: published ?? DateTime.now(),
        ));
      }
    } catch (_) {}
    return items;
  }

  static String relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }
}
```

**Step 3: 写离线 RSS 解析单元测试**

```dart
// test/news_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:future_world_corn_mobile/services/news_service.dart';

void main() {
  group('NewsService._parseRss', () {
    test('parses valid RSS XML', () {
      const xml = '''
      <rss version="2.0"><channel>
        <item>
          <title>比特币突破新高</title>
          <link>https://example.com/1</link>
          <pubDate>Fri, 28 Aug 2026 10:00:00 GMT</pubDate>
          <source>CoinDesk</source>
        </item>
      </channel></rss>''';
      final items = NewsService._parseRss(xml);
      expect(items.length, 1);
      expect(items.first.title, '比特币突破新高');
      expect(items.first.source, 'CoinDesk');
    });

    test('returns empty for broken XML', () {
      expect(NewsService._parseRss('not xml at all'), isEmpty);
    });

    test('relativeTime formats', () {
      final now = DateTime.now();
      expect(NewsService.relativeTime(now.subtract(const Duration(minutes: 1))), '1分钟前');
      expect(NewsService.relativeTime(now.subtract(const Duration(hours: 2))), '2小时前');
    });
  });
}
```

**Step 4: 运行测试验证（下划线私有方法在 test 目录可见）**

Run: `flutter test test/news_service_test.dart`
Expected: 3 passing

**Step 5: Commit**

```bash
git add pubspec.yaml lib/services/news_service.dart test/news_service_test.dart
git commit -m "feat: add NewsService with Google News RSS parsing"
```

---

### Task 2: 创建 MorePage（更多入口页）

**Files:**
- Create: `lib/pages/more_page.dart`

**Step 1: 写页面（参照 settings_page 的 Scaffold 风格）**

```dart
// lib/pages/more_page.dart
import 'package:flutter/material.dart';
import 'package:future_world_corn_mobile/pages/delegate_page.dart';
import 'package:future_world_corn_mobile/pages/humanhouse_page.dart';
import 'package:future_world_corn_mobile/pages/settings_page.dart';
import 'package:future_world_corn_mobile/theme/app_theme.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('更多', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppTheme.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _EntryCard(
            icon: Icons.swap_horiz,
            iconColor: AppTheme.primary,
            title: '委托管理',
            subtitle: 'CORN ↔ govCORN 存取与投票权委托',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DelegatePage())),
          ),
          const SizedBox(height: 12),
          _EntryCard(
            icon: Icons.gavel,
            iconColor: AppTheme.no,
            title: 'HumanHouse 争议',
            subtitle: '查看与发起市场争议、参与投票',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HumanHousePage())),
          ),
          const SizedBox(height: 12),
          _EntryCard(
            icon: Icons.settings,
            iconColor: AppTheme.muted,
            title: '网络设置',
            subtitle: 'RPC 节点与钱包地址配置',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _EntryCard({required this.icon, required this.iconColor, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: iconColor.withAlpha(25),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.muted),
        onTap: onTap,
      ),
    );
  }
}
```

**Step 2: 验证编译**

Run: `flutter analyze`
Expected: 无 error

**Step 3: Commit**

```bash
git add lib/pages/more_page.dart
git commit -m "feat: add More page with delegate/humanhouse/settings entries"
```

---

### Task 3: 底部导航重构为 4 Tab

**Files:**
- Modify: `lib/pages/navigation_shell.dart`

**Step 1: 修改 NavigationShell**

将 `_pages`、`_labels`、`_icons` 改为 4 项，导入 `more_page.dart`,移除 `delegate_page.dart`、`governance_page.dart` 之外的直接引入（保留 HomePage/PortfolioPage/GovernancePage/MorePage）：

```dart
import 'package:flutter/material.dart';
import 'package:future_world_corn_mobile/theme/app_theme.dart';
import 'package:future_world_corn_mobile/pages/home_page.dart';
import 'package:future_world_corn_mobile/pages/portfolio_page.dart';
import 'package:future_world_corn_mobile/pages/governance_page.dart';
import 'package:future_world_corn_mobile/pages/more_page.dart';

class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key});
  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  int _selectedIndex = 0;

  static const _pages = <Widget>[
    HomePage(),
    PortfolioPage(),
    GovernancePage(),
    MorePage(),
  ];

  static const _labels = <String>['首页', '投资', '治理', '更多'];
  static const _icons = <IconData>[
    Icons.home,
    Icons.account_balance_wallet,
    Icons.how_to_vote,
    Icons.more_horiz,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.background,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.muted,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        elevation: 8,
        items: List.generate(_pages.length, (i) => BottomNavigationBarItem(icon: Icon(_icons[i]), label: _labels[i])),
      ),
    );
  }
}
```

**Step 2: 验证编译**

Run: `flutter analyze`
Expected: 无 error（delegate/humanhouse 不再被 shell 引用但文件仍在，不报错）

**Step 3: Commit**

```bash
git add lib/pages/navigation_shell.dart
git commit -m "feat: restructure bottom nav to 4 tabs (home/portfolio/governance/more)"
```

---

### Task 4: 首页重构（轮播 + Breaking News + Hot Topics + 列表）

**Files:**
- Modify: `lib/pages/home_page.dart`（重构 build 方法 + 新增子组件）

**Step 1: 导入 NewsService**

在 `home_page.dart` 顶部加入：
```dart
import 'package:future_world_corn_mobile/services/news_service.dart';
```

**Step 2: 重构 `_HomePageState`**

新增状态：`List<NewsItem> _news = [];` `bool _newsLoading = true;`，在 `initState` 中调用 `_loadNews()`：

```dart
@override
void initState() {
  super.initState();
  _loadNews();
}

Future<void> _loadNews() async {
  try {
    final news = await NewsService.fetch(NewsService.defaultKeywords);
    if (mounted) setState(() { _news = news; _newsLoading = false; });
  } catch (_) {
    if (mounted) setState(() => _newsLoading = false);
  }
}
```

**Step 3: 在 `data:` 分支的 ListView 顶部插入新区块**

在现有 `_TrendingSection` **之前**（或替换）加入，把 ListView children 改为：

```dart
children: [
  _FeaturedCarousel(markets: openMarkets, onSelect: _goToDetail),
  const SizedBox(height: 16),
  if (_news.isNotEmpty)
    _BreakingNewsSection(items: _news,
      onTap: (item) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.title}\n${item.link}')))),
  const SizedBox(height: 16),
  _HotTopicsSection(markets: markets, onSelect: (id) {
    setState(() => _filters = _filters.copyWith(category: id));
  }),
  const SizedBox(height: 16),
  _SearchBar(...),  // 原样保留
  ...
],
```

`openMarkets = markets.where((m) => m.isOpen).toList()`

**Step 4: 新增三个子组件（追加到文件底部，_TrendingSection 附近）**

`_FeaturedCarousel`：
```dart
class _FeaturedCarousel extends StatelessWidget {
  final List<MarketData> markets;
  final ValueChanged<int> onSelect;
  const _FeaturedCarousel({required this.markets, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    if (markets.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.local_fire_department, color: AppTheme.no, size: 18),
        const SizedBox(width: 6),
        Text('热门市场', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.foreground)),
      ]),
      const SizedBox(height: 12),
      SizedBox(
        height: 170,
        child: PageView.builder(
          controller: PageController(viewportFraction: 0.9),
          itemCount: markets.length,
          itemBuilder: (context, i) => _CarouselCard(market: markets[i], onTap: () => onSelect(markets[i].id)),
        ),
      ),
    ]);
  }
}

class _CarouselCard extends StatelessWidget {
  final MarketData market;
  final VoidCallback onTap;
  const _CarouselCard({required this.market, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border, width: 0.5),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(cat.categoryLabel(cat.classifyQuestion(market.question)),
              style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(market.statusLabel, style: TextStyle(fontSize: 11, color: AppTheme.muted)),
          ]),
          const SizedBox(height: 8),
          Expanded(child: Text(market.question,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.foreground))),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${market.yesPct.toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppTheme.yes)),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${market.totalPool.toStringAsFixed(2)} CORN',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.foreground)),
              Text('截止 ${DateTime.fromMillisecondsSinceEpoch(market.deadline * 1000).month}/${DateTime.fromMillisecondsSinceEpoch(market.deadline * 1000).day}',
                style: TextStyle(fontSize: 10, color: AppTheme.muted)),
            ]),
          ]),
        ]),
      ),
    );
  }
}
```

`_BreakingNewsSection`：
```dart
class _BreakingNewsSection extends StatelessWidget {
  final List<NewsItem> items;
  final ValueChanged<NewsItem> onTap;
  const _BreakingNewsSection({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.bolt, color: AppTheme.no, size: 18),
        const SizedBox(width: 6),
        const Text('Breaking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        Text('实时新闻', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
      ]),
      const SizedBox(height: 8),
      ...items.take(5).map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: InkWell(
          onTap: () => onTap(item),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border, width: 0.5)),
            child: Row(children: [
              const Icon(Icons.circle, color: AppTheme.no, size: 8),
              const SizedBox(width: 8),
              Expanded(child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: AppTheme.foreground))),
              const SizedBox(width: 8),
              Text(NewsService.relativeTime(item.published), style: TextStyle(fontSize: 10, color: AppTheme.muted)),
            ]),
          ),
        ),
      )),
    ]);
  }
}
```

`_HotTopicsSection`：
```dart
class _HotTopicsSection extends StatelessWidget {
  final List<MarketData> markets;
  final ValueChanged<String> onSelect;
  const _HotTopicsSection({required this.markets, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final open = markets.where((m) => m.isOpen).toList();
    final pools = <String, double>{};
    for (final m in open) {
      final id = cat.classifyQuestion(m.question);
      pools[id] = (pools[id] ?? 0) + m.totalPool;
    }
    final sorted = pools.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Hot Topics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.foreground)),
      const SizedBox(height: 8),
      SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: sorted.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final id = sorted[i].key;
            final label = cat.categoryLabel(id);
            final pool = sorted[i].value;
            return ActionChip(
              avatar: const Icon(Icons.local_fire_department, color: AppTheme.no, size: 14),
              label: Text('$label $pool'),
              labelStyle: TextStyle(fontSize: 12, color: AppTheme.foreground),
              onPressed: () => onSelect(id),
            );
          },
        ),
      ),
    ]);
  }
}
```

**Step 5: 验证编译**

Run: `flutter analyze`
Expected: 无 error。若 `_loadNews` 中 `_newsLoading` 未用导致 warning，可移除该字段或加 `// ignore`。

**Step 6: Commit**

```bash
git add lib/pages/home_page.dart
git commit -m "feat: add featured carousel, breaking news, hot topics to homepage"
```

---

### Task 5: 详情页新增相关新闻区块

**Files:**
- Modify: `lib/pages/market_detail_page.dart`

**Step 1: 状态 + 加载**

在 `_MarketDetailPageState` 加字段：`List<NewsItem> _relatedNews = [];`
import `news_service.dart`。
在 `_loadOwnerData()` 成功后调用 `_loadRelatedNews(question)`：

```dart
Future<void> _loadRelatedNews(String question) async {
  try {
    final id = cat.classifyQuestion(question);
    final keywords = <String>[];
    if (id == cat.categoryOther || id == 'tech' || id == 'economy') {
      keywords.addAll(['crypto', '区块链', '市场']);
    } else {
      keywords.addAll(NewsService.defaultKeywords.where((k) => k != 'crypto'));
      keywords.add(id);
    }
    if (keywords.isNotEmpty) {
      final news = await NewsService.fetch(keywords.take(2).toList());
      if (mounted) setState(() => _relatedNews = news.take(5).toList());
    }
  } catch (_) {}
}
```

**Step 2: 在详情页 Column 中插入新闻区块**

找到"市场时间线"标题前面的位置，插入：
```dart
if (_relatedNews.isNotEmpty) ...[
  const Divider(),
  Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
    const Icon(Icons.article_outlined, color: AppTheme.primary, size: 18),
    const SizedBox(width: 6),
    Text('相关新闻', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.foreground)),
  ])),
  ..._relatedNews.map((n) => InkWell(
    onTap: () {
      Clipboard.setData(ClipboardData(text: n.link));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('链接已复制'), duration: Duration(seconds: 1)));
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Text(n.title, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, color: AppTheme.foreground))),
        const SizedBox(width: 8),
        Text(NewsService.relativeTime(n.published), style: TextStyle(fontSize: 10, color: AppTheme.muted)),
      ]),
    ),
  )),
],
```

（`cat` 已在 market_detail_page.dart 顶部以 `as cat` 导入，可直接用。）

**Step 3: 验证编译**

Run: `flutter analyze`
Expected: 无 error

**Step 4: Commit**

```bash
git add lib/pages/market_detail_page.dart
git commit -m "feat: add related news section to market detail page"
```

---

### Task 6: 更新集成测试（4 Tab + 新首页区块 + More 页）

**Files:**
- Modify: `integration_test/app_test.dart`

**Step 1: 更新底部导航断言**

- "shows app title and bottom navigation"：labels 改为 `首页/投资/治理/更多`，去掉 `委托/争议`。
- "switches to Delegate tab" 改为 "switches to Governance tab"（治理已在 4 Tab）：验证 `find.text('治理')` 出现在 AppBar（用 `find.descendant(of: find.byType(AppBar), matching: find.text('治理'))`，避免与导航标签冲突）。
- 新增 "switches to More tab"：tap `更多`，断言 `find.text('委托管理')`、`find.text('HumanHouse 争议')`（More 页入口卡）。
- "switches to HumanHouse tab" 改为通过 More 页进入：tap `更多` → tap `HumanHouse 争议` → 断言 `find.text('HumanHouse 争议')` 出现（AppBar）。

**Step 2: 新增首页区块断言**

- "homepage shows featured carousel"：`find.text('热门市场')`（若存在进行中市场）；断言 `PagendView`（`find.byType(PageView)`）存在或热门区块标题存在。
- "homepage shows hot topics"：`find.text('Hot Topics')` 存在。
- Breaking News：`find.text('Breaking')` 存在 **或** 网络失败时空态不报错（不断言失败）。

**Step 3: 更新测试内容细节**

统一把 sample 用例的等待时间调整（首页新增 RPC + RSS 双数据源，pumpAndSettle 设更长，如 8s）。

**Step 4: 运行集成测试**

Run: `flutter test integration_test/app_test.dart -d emulator`
Expected: 全部用例通过（网络依赖用例允许空态降级）

**Step 5: Commit**

```bash
git add integration_test/app_test.dart
git commit -m "test: update integration tests for 4-tab nav and new homepage sections"
```

---

### Task 7: 全量验证 + 构建 APK

**Files:**
- 无新增（运行验证）

**Step 1: 单元测试**

Run: `flutter test test/`
Expected: 全部通过（含新增 news_service_test.dart）

**Step 2: 静态分析**

Run: `flutter analyze`
Expected: 0 error、0 warning

**Step 3: 构建并安装**

Run: `flutter build apk --debug` → `adb install -r build/app/outputs/flutter-apk/app-debug.apk`
Expected: 构建成功，安装成功

**Step 4: 集成测试（模拟器）**

Run: `flutter test integration_test/app_test.dart -d emulator`
Expected: 全部通过

**Step 5: Commit（如有残余改动）**

```bash
git add -A
git commit -m "chore: final verification for polymarket-style redesign"
```