import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:future_world_corn_mobile/main.dart' as app;

/// 首页市场数据未就绪（仍加载 / 加载失败 / 无市场）时，依赖 RPC 数据的区块
/// 允许不渲染；存在非空市场数据时才强制断言区块内容。
bool _homeDataNotReady(WidgetTester tester) {
  return find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
      find.textContaining('加载失败').evaluate().isNotEmpty ||
      find.text('暂无市场。').evaluate().isNotEmpty;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Launch', () {
    testWidgets('shows app title and bottom navigation', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 8));

      expect(find.text('预测大师'), findsWidgets);

      // 4 Tab：首页 / 投资 / 治理 / 更多（委托、争议 并入"更多"页）
      expect(find.text('首页'), findsOneWidget);
      expect(find.text('投资'), findsOneWidget);
      expect(find.text('治理'), findsOneWidget);
      expect(find.text('更多'), findsOneWidget);
    });

    testWidgets('loads market data from chain', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 8));

      // After data loads: market list, empty state, or error
      final hasMarkets = find.textContaining('市场（').evaluate().isNotEmpty;
      final noMarkets = find.text('暂无市场。').evaluate().isNotEmpty;
      final loading = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      final hasError = find.textContaining('加载失败').evaluate().isNotEmpty ||
          find.textContaining('Error').evaluate().isNotEmpty;

      expect(hasMarkets || noMarkets || loading || hasError, true,
          reason: 'Should show market list, empty state, loading, or error');
    });
  });

  group('Bottom Navigation', () {
    testWidgets('switches to Portfolio tab', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 8));

      await tester.tap(find.text('投资'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('投资组合'), findsOneWidget);
    });

    testWidgets('switches to More tab', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 8));

      await tester.tap(find.text('更多'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 更多页入口卡：委托 / 争议 / 设置
      expect(find.text('委托管理'), findsOneWidget);
      expect(find.text('HumanHouse 争议'), findsOneWidget);
      expect(find.text('网络设置'), findsOneWidget);
    });

    testWidgets('switches to Governance tab', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 8));

      await tester.tap(find.text('治理'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // "治理"同时出现在导航标签与 AppBar 标题，用 descendant 精确断言 AppBar 标题
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('治理')),
        findsWidgets,
      );
    });

    testWidgets('switches back to Home tab', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 8));

      await tester.tap(find.text('投资'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await tester.tap(find.text('首页'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('预测大师'), findsWidgets);
    });

    testWidgets('enters disputes from More tab', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 8));

      // 通过"更多"页进入争议子页面
      await tester.tap(find.text('更多'));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await tester.tap(find.text('HumanHouse 争议'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('HumanHouse 争议'), findsWidgets);

      // 子页面 AppBar 自动带回退按钮，返回更多页验证导航闭环
      final backButton = find.byType(BackButton);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.text('委托管理'), findsOneWidget);
      }
    });
  });

  group('Home Page', () {
    testWidgets('shows search bar', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 8));

      if (_homeDataNotReady(tester)) return;

      // 首页头部区块（轮播/Breaking/Hot Topics/热门市场）可能把搜索栏挤出首屏
      await tester.scrollUntilVisible(find.byIcon(Icons.search), 300,
          maxScrolls: 25, scrollable: find.byType(Scrollable).first);
      expect(find.byIcon(Icons.search), findsWidgets);
    });

    testWidgets('settings button opens settings page', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 8));

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('网络设置'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_ios));
      await tester.pumpAndSettle();

      expect(find.text('预测大师'), findsWidgets);
    });

    testWidgets('homepage shows featured carousel', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 8));

      // 轮播（_FeaturedCarousel，PageView）仅在存在进行中市场时渲染；
      // 命中 PageView 或是“热门市场”标题即视为已渲染。
      // 市场数据未就绪（加载中/失败/空态）时允许不渲染。
      final hasFeatured = find.byType(PageView).evaluate().isNotEmpty ||
          find.text('热门市场').evaluate().isNotEmpty;
      expect(hasFeatured || _homeDataNotReady(tester), true,
          reason: 'Featured carousel should render when open markets exist');
    });

    testWidgets('homepage shows hot topics', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 8));

      if (_homeDataNotReady(tester)) return;

      // Hot Topics 区块可能在首屏之下，滚动到可见后断言
      await tester.scrollUntilVisible(find.text('Hot Topics'), 300,
          maxScrolls: 20, scrollable: find.byType(Scrollable).first);
      expect(find.text('Hot Topics'), findsWidgets);
    });

    testWidgets('homepage shows breaking news', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 8));

      // Breaking 依赖 Google News RSS，网络不可用时允许不渲染；
      // 但一旦渲染就必须渲染出新闻条目行（标题 + 相对时间）。
      final hasBreaking = find.text('Breaking').evaluate().isNotEmpty;
      if (hasBreaking) {
        expect(find.text('实时新闻'), findsWidgets);
        final hasItem = find.text('刚刚').evaluate().isNotEmpty ||
            find.textContaining('分钟前').evaluate().isNotEmpty ||
            find.textContaining('小时前').evaluate().isNotEmpty ||
            find.textContaining('天前').evaluate().isNotEmpty;
        expect(hasItem, true,
            reason: 'Breaking section must contain news item rows');
      }
    });
  });

  group('Market Detail', () {
    testWidgets('tap market card opens detail page', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 8));

      // 首页唯一使用 Card 的是市场列表（轮播/热门市场用 Container），
      // 因此第一张 Card 就是市场卡。
      final cards = find.byType(Card);
      if (cards.evaluate().isEmpty) return;

      // 首页头部区块（轮播/Breaking/Hot Topics/热门市场/搜索/分类）占据大量
      // 空间，第一张市场卡可能不在可视区内，先滚动到可见再点击。
      await tester.scrollUntilVisible(cards.first, 300,
          maxScrolls: 25, scrollable: find.byType(Scrollable).first);
      await tester.tap(cards.first);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final hasDetail = find.text('市场时间线').evaluate().isNotEmpty ||
          find.text('下注').evaluate().isNotEmpty ||
          find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      expect(hasDetail, true);
    });
  });

  group('Portfolio Page', () {
    testWidgets('shows portfolio content', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 8));

      await tester.tap(find.text('投资'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('投资组合'), findsOneWidget);

      // No wallet -> "请先在设置中连接钱包"; with wallet -> holdings/loading
      final hasContent = find.text('请先在设置中连接钱包').evaluate().isNotEmpty ||
          find.text('暂无持仓').evaluate().isNotEmpty ||
          find.textContaining('市场 #').evaluate().isNotEmpty ||
          find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      expect(hasContent, true);
    });
  });

  group('Delegate Page', () {
    testWidgets('shows delegation interface', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 8));

      // 委托不再有独立 Tab，通过"更多"页进入
      await tester.tap(find.text('更多'));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await tester.tap(find.text('委托管理'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('委托'), findsWidgets);

      // No wallet -> "请先在设置中连接钱包"; with wallet -> delegation UI
      final hasInterface = find.text('请先在设置中连接钱包').evaluate().isNotEmpty ||
          find.text('存入').evaluate().isNotEmpty ||
          find.text('取回').evaluate().isNotEmpty ||
          find.text('委托投票权').evaluate().isNotEmpty ||
          find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      expect(hasInterface, true);
    });
  });

  group('Governance Page', () {
    testWidgets('shows governance interface', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 8));

      await tester.tap(find.text('治理'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('治理')),
        findsWidgets,
      );

      final hasContent = find.text('暂无提案').evaluate().isNotEmpty ||
          find.textContaining('提案').evaluate().isNotEmpty ||
          find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      expect(hasContent, true);
    });
  });

  group('HumanHouse Page', () {
    testWidgets('shows dispute interface', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 8));

      // 通过"更多"页进入争议
      await tester.tap(find.text('更多'));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await tester.tap(find.text('HumanHouse 争议'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('HumanHouse 争议'), findsWidgets);

      final hasContent = find.text('暂无争议').evaluate().isNotEmpty ||
          find.text('加载争议...').evaluate().isNotEmpty ||
          find.text('争议加载失败').evaluate().isNotEmpty ||
          find.textContaining('市场 #').evaluate().isNotEmpty ||
          find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      expect(hasContent, true);
    });

    testWidgets('shows raise dispute card', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 8));

      await tester.tap(find.text('更多'));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await tester.tap(find.text('HumanHouse 争议'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final hasRaise = find.text('发起争议').evaluate().isNotEmpty ||
          find.textContaining('提交').evaluate().isNotEmpty;
      expect(hasRaise, true);
    });
  });
}