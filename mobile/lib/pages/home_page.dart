import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:future_world_corn_mobile/providers/market_provider.dart';
import 'package:future_world_corn_mobile/theme/app_theme.dart';
import 'package:future_world_corn_mobile/lib/categories.dart' as cat;
import 'package:future_world_corn_mobile/lib/filters.dart';
import 'package:future_world_corn_mobile/pages/market_detail_page.dart';
import 'package:future_world_corn_mobile/pages/settings_page.dart';
import 'package:future_world_corn_mobile/services/news_service.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  FilterState _filters = const FilterState();
  String _searchText = '';
  List<NewsItem> _news = [];

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    try {
      final news = await NewsService.fetch(NewsService.defaultKeywords);
      if (mounted) setState(() => _news = news);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final marketsAsync = ref.watch(marketsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.trending_up, color: AppTheme.primary, size: 24),
            SizedBox(width: 8),
            Text('预测大师', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.foreground)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: AppTheme.muted),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppTheme.border),
        ),
      ),
      body: marketsAsync.when(
        loading: () => _buildLoading(),
        error: (e, _) => _buildError(e),
        data: (markets) {
          if (markets.isEmpty) {
            return Center(child: Text('暂无市场。', style: TextStyle(color: AppTheme.muted)));
          }
          final filtered = filterAndSort(markets, _filters);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(marketsProvider),
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _FeaturedCarousel(markets: markets.where((m) => m.isOpen).toList(), onSelect: _goToDetail),
                const SizedBox(height: 16),
                if (_news.isNotEmpty)
                  _BreakingNewsSection(
                    items: _news,
                    onTap: (item) => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${item.title}\n${item.link}'), duration: const Duration(seconds: 3))),
                  ),
                const SizedBox(height: 16),
                _HotTopicsSection(markets: markets, onSelect: (id) {
                  setState(() => _filters = _filters.copyWith(category: id));
                }),
                const SizedBox(height: 16),
                _TrendingSection(markets: markets, onSelect: _goToDetail),
                SizedBox(height: 16),
                _SearchBar(
                  filters: _filters,
                  searchText: _searchText,
                  onSearchChanged: (v) {
                    setState(() {
                      _searchText = v;
                      _filters = _filters.copyWith(search: v);
                    });
                  },
                  onSortChanged: (v) => setState(() => _filters = _filters.copyWith(sort: v)),
                  onStatusChanged: (v) => setState(() => _filters = _filters.copyWith(status: v)),
                  totalCount: markets.length,
                  filteredCount: filtered.length,
                ),
                SizedBox(height: 12),
                _CategoryChips(
                  selected: _filters.category,
                  onSelected: (id) => setState(() => _filters = _filters.copyWith(category: id)),
                ),
                SizedBox(height: 12),
                Text('市场（${filtered.length}）', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.foreground)),
                SizedBox(height: 12),
                ...filtered.map((m) => Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: _MarketCard(market: m, onTap: () => _goToDetail(m.id)),
                )),
                if (filtered.isEmpty && markets.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('没有匹配的市场。', style: TextStyle(color: AppTheme.muted))),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _goToDetail(int id) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => MarketDetailPage(marketId: id)));
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
          ),
          SizedBox(height: 12),
          Text('正在连接 RPC 节点...', style: TextStyle(color: AppTheme.muted, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildError(Object e) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppTheme.no, size: 48),
            SizedBox(height: 12),
            Text('加载失败：$e', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.no)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(marketsProvider),
              child: Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendingSection extends StatelessWidget {
  final List<MarketData> markets;
  final ValueChanged<int> onSelect;
  const _TrendingSection({required this.markets, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final sorted = markets
        .where((m) => m.status == 0 && m.totalPool > 0)
        .toList()
      ..sort((a, b) => b.totalPool.compareTo(a.totalPool));
    final top = sorted.take(5).toList();
    if (top.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('热门市场', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.foreground)),
        SizedBox(height: 12),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: top.length,
            separatorBuilder: (_, __) => SizedBox(width: 16),
            itemBuilder: (ctx, i) {
              final m = top[i];
              final cid = cat.classifyQuestion(m.question);
              return GestureDetector(
                onTap: () => onSelect(m.id),
                child: Container(
                  width: 280,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _CategoryBadge(categoryId: cid),
                          Text(_formatDate(m.deadline), style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                        ],
                      ),
                      SizedBox(height: 8),
                      Expanded(
                        child: Text(m.question,
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.foreground)),
                      ),
                      SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${m.yesPct.toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppTheme.yes)),
                          SizedBox(width: 4),
                          Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Text('YES', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text('资金池 ${m.totalPool.toStringAsFixed(2)} CORN', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final FilterState filters;
  final String searchText;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<SortKey> onSortChanged;
  final ValueChanged<StatusFilter> onStatusChanged;
  final int totalCount;
  final int filteredCount;
  const _SearchBar({
    required this.filters, required this.searchText,
    required this.onSearchChanged, required this.onSortChanged, required this.onStatusChanged,
    required this.totalCount, required this.filteredCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: '搜索市场...',
            prefixIcon: Icon(Icons.search, color: AppTheme.muted, size: 20),
            isDense: true,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _Dropdown<SortKey>(
              value: filters.sort,
              items: [
                _DropdownItem(SortKey.newest, '最新'),
                _DropdownItem(SortKey.pool, '资金池最大'),
                _DropdownItem(SortKey.deadline, '即将截止'),
                _DropdownItem(SortKey.odds, '赔率最高'),
              ],
              onChanged: onSortChanged,
            )),
            SizedBox(width: 8),
            Expanded(child: _Dropdown<StatusFilter>(
              value: filters.status,
              items: [
                _DropdownItem(StatusFilter.all, '全部'),
                _DropdownItem(StatusFilter.active, '进行中'),
                _DropdownItem(StatusFilter.pending, '待结算'),
                _DropdownItem(StatusFilter.resolved, '已结算'),
                _DropdownItem(StatusFilter.cancelled, '已取消'),
              ],
              onChanged: onStatusChanged,
            )),
            if (filteredCount < totalCount) ...[
              SizedBox(width: 8),
              Text('显示 $filteredCount/$totalCount', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
            ],
          ],
        ),
      ],
    );
  }
}

class _DropdownItem<T> {
  final T value;
  final String label;
  const _DropdownItem(this.value, this.label);
}

class _Dropdown<T> extends StatelessWidget {
  final T value;
  final List<_DropdownItem<T>> items;
  final ValueChanged<T> onChanged;
  const _Dropdown({required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        underline: SizedBox.shrink(),
        style: TextStyle(fontSize: 13, color: AppTheme.foreground),
        items: items.map((i) => DropdownMenuItem(value: i.value, child: Text(i.label))).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  const _CategoryChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final items = [('all', '全部'), ...cat.categories.map((c) => (c.id, c.label)), (cat.categoryOther, '其他')];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          final isSelected = selected == item.$1;
          return Padding(
            padding: EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(item.$2),
              selected: isSelected,
              onSelected: (_) => onSelected(item.$1),
              selectedColor: AppTheme.primary.withAlpha(25),
              backgroundColor: AppTheme.card,
              side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.border),
              labelStyle: TextStyle(
                fontSize: 13,
                color: isSelected ? AppTheme.primary : AppTheme.foreground,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MarketCard extends StatelessWidget {
  final MarketData market;
  final VoidCallback onTap;
  const _MarketCard({required this.market, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final m = market;
    final cid = cat.classifyQuestion(m.question);
    final isResolved = m.status == 1;
    final isPending = m.status == 0 && m.deadline * 1000 < DateTime.now().millisecondsSinceEpoch;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(m.question,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.foreground),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  SizedBox(width: 8),
                  _StatusBadge(status: m.status, isPending: isPending),
                ],
              ),
              SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${m.yesPct.toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.yes)),
                  SizedBox(width: 6),
                  Padding(
                    padding: EdgeInsets.only(bottom: 3),
                    child: Text('YES 概率', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                  ),
                  Spacer(),
                  Text('截止 ${_formatDate(m.deadline)}',
                    style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                ],
              ),
              SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: [
                      Expanded(
                        flex: (m.yesPct * 10).toInt(),
                        child: Container(color: AppTheme.yes),
                      ),
                      Expanded(
                        flex: ((100 - m.yesPct) * 10).toInt(),
                        child: Container(color: AppTheme.no),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  _CopyableId(id: m.id),
                  Spacer(),
                  Text('${m.totalPool.toStringAsFixed(2)} CORN',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.foreground)),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Text('YES ${m.outcomeYes.toStringAsFixed(2)} CORN',
                    style: TextStyle(fontSize: 12, color: AppTheme.yes, fontWeight: FontWeight.w500)),
                  Spacer(),
                  Text('NO ${m.outcomeNo.toStringAsFixed(2)} CORN',
                    style: TextStyle(fontSize: 12, color: AppTheme.no, fontWeight: FontWeight.w500)),
                ],
              ),
              if (isResolved)
                Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('结果：${m.result ? 'YES 胜' : 'NO 胜'}',
                    style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                ),
              SizedBox(height: 8),
              Row(
                children: [
                  _CategoryBadge(categoryId: cid),
                  Spacer(),
                  SizedBox(
                    height: 32,
                    child: OutlinedButton(
                      onPressed: onTap,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        textStyle: TextStyle(fontSize: 13),
                      ),
                      child: Text('查看详情'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CopyableId extends StatelessWidget {
  final int id;
  const _CopyableId({required this.id});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: '#$id'));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('市场 #$id 已复制'), duration: Duration(seconds: 1)),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('#$id', style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppTheme.muted)),
            SizedBox(width: 4),
            Icon(Icons.copy, size: 12, color: AppTheme.muted),
          ],
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String categoryId;
  const _CategoryBadge({required this.categoryId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(cat.categoryLabel(categoryId),
        style: TextStyle(fontSize: 11, color: AppTheme.muted)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final int status;
  final bool isPending;
  const _StatusBadge({required this.status, required this.isPending});

  @override
  Widget build(BuildContext context) {
    final label = status == 1 ? '已结算' : status == 2 ? '已取消' : isPending ? '待结算' : '进行中';
    final color = status == 1 ? AppTheme.yes : status == 2 ? AppTheme.muted : AppTheme.primary;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }
}

String _formatDate(int timestamp) {
  final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
}

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
        const Text('热门市场', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
      const Text('Hot Topics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
