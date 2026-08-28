import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:future_world_corn_mobile/providers/market_provider.dart';
import 'package:future_world_corn_mobile/providers/wallet_provider.dart';
import 'package:future_world_corn_mobile/providers/rpc_provider.dart';
import 'package:future_world_corn_mobile/services/contract_service.dart';
import 'package:future_world_corn_mobile/services/price_history_service.dart';
import 'package:future_world_corn_mobile/services/dispute_service.dart';
import 'package:future_world_corn_mobile/services/news_service.dart';
import 'package:future_world_corn_mobile/theme/app_theme.dart';
import 'package:future_world_corn_mobile/contracts/addresses.dart' as addr;
import 'package:future_world_corn_mobile/lib/categories.dart' as cat;

class MarketDetailPage extends ConsumerStatefulWidget {
  final int marketId;
  const MarketDetailPage({super.key, required this.marketId});

  @override
  ConsumerState<MarketDetailPage> createState() => _MarketDetailPageState();
}

class _MarketDetailPageState extends ConsumerState<MarketDetailPage> {
  String? _ownerAddress;
  bool _isResolver = false;
  int _feeBps = 200;
  BigInt _balance = BigInt.zero;
  BigInt _allowance = BigInt.zero;
  BigInt _sharesYes = BigInt.zero;
  BigInt _sharesNo = BigInt.zero;
  bool _claimed = false;
  List<DisputeData> _disputes = [];
  List<PricePoint> _priceHistory = [];
  bool _userLoading = false;
  List<NewsItem> _relatedNews = [];

  @override
  void initState() {
    super.initState();
    _loadOwnerData();
  }

  Future<void> _loadOwnerData() async {
    final rpcUrl = ref.read(rpcUrlProvider);
    try {
      final owner = await ContractService.marketOwner(rpcUrl);
      final fee = await ContractService.defaultFeeBps(rpcUrl);
      if (mounted) {
        setState(() {
          _ownerAddress = owner;
          _feeBps = fee;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadUserData(String rpcUrl, String address, int marketId) async {
    if (!mounted) return;
    setState(() => _userLoading = true);
    try {
      final results = await Future.wait([
        ContractService.tokenBalance(rpcUrl, address),
        ContractService.tokenAllowance(rpcUrl, address),
        ContractService.userSharesYes(rpcUrl, marketId, address),
        ContractService.userSharesNo(rpcUrl, marketId, address),
        ContractService.claimed(rpcUrl, marketId, address),
        ContractService.isResolver(rpcUrl, address),
      ]);
      if (mounted) {
        setState(() {
          _balance = results[0] as BigInt;
          _allowance = results[1] as BigInt;
          _sharesYes = results[2] as BigInt;
          _sharesNo = results[3] as BigInt;
          _claimed = results[4] as bool;
          _isResolver = results[5] as bool;
          _userLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _userLoading = false);
    }
  }

  Future<void> _loadDisputes(String rpcUrl, int marketId) async {
    try {
      final disputes = await DisputeService.fetchForMarket(rpcUrl, marketId);
      if (mounted) setState(() => _disputes = disputes);
    } catch (_) {}
  }

  Future<void> _loadPriceHistory(String rpcUrl, int marketId, double yesPool, double noPool) async {
    try {
      final history = await PriceHistoryService.fetch(rpcUrl, marketId, yesPool, noPool);
      if (mounted) setState(() => _priceHistory = history);
    } catch (_) {}
  }

  Future<void> _loadRelatedNews(String question) async {
    try {
      final id = cat.classifyQuestion(question);
      final keywords = <String>[];
      for (final c in cat.categories) {
        if (c.id == id) {
          keywords.addAll(c.keywords);
          break;
        }
      }
      if (keywords.isEmpty) keywords.addAll(NewsService.defaultKeywords);
      final news = await NewsService.fetch(keywords.take(2).toList());
      if (mounted) setState(() => _relatedNews = news.take(5).toList());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final marketAsync = ref.watch(marketDetailProvider(widget.marketId));
    final rpcUrl = ref.watch(rpcUrlProvider);
    final wallet = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.muted),
          onPressed: () => Navigator.pop(context),
        ),
        title: SizedBox.shrink(),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppTheme.border),
        ),
      ),
      body: marketAsync.when(
        loading: () => _buildLoading(),
        error: (e, _) => _buildError(e),
        data: (market) {
          if (market == null) return _buildNotFound();
          _onMarketLoaded(rpcUrl, market, wallet.address);
          return _buildDetail(rpcUrl, market, wallet);
        },
      ),
    );
  }

  bool _loaded = false;
  void _onMarketLoaded(String rpcUrl, MarketData market, String? address) {
    if (_loaded) return;
    _loaded = true;
    _loadDisputes(rpcUrl, market.id);
    _loadPriceHistory(rpcUrl, market.id, market.outcomeYes, market.outcomeNo);
    _loadRelatedNews(market.question);
    if (address != null) {
      _loadUserData(rpcUrl, address, market.id);
    }
  }

  Widget _buildLoading() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
        SizedBox(height: 12),
        Text('正在连接 RPC 节点...', style: TextStyle(color: AppTheme.muted, fontSize: 14)),
      ]),
    );
  }

  Widget _buildError(Object e) {
    return Center(
      child: Padding(padding: EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('加载失败：$e', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.no)),
        SizedBox(height: 16),
        ElevatedButton(onPressed: () => Navigator.pop(context), child: Text('返回')),
      ])),
    );
  }

  Widget _buildNotFound() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('未找到市场', style: TextStyle(color: AppTheme.muted)),
      SizedBox(height: 16),
      OutlinedButton(onPressed: () => Navigator.pop(context), child: Text('返回')),
    ]));
  }

  Widget _buildDetail(String rpcUrl, MarketData m, WalletState wallet) {
    final isOpen = m.status == 0;
    final isResolved = m.status == 1;
    final deadlinePassed = m.deadline * 1000 < DateTime.now().millisecondsSinceEpoch;
    final cid = cat.classifyQuestion(m.question);
    final isOwner = wallet.connected && _ownerAddress != null &&
        wallet.address!.toLowerCase() == _ownerAddress!.toLowerCase();
    final canResolve = isOwner || _isResolver;
    final hasShares = _sharesYes + _sharesNo > BigInt.zero;
    final userBalance = _balance.toDouble() / 1e18;
    final userAllowance = _allowance.toDouble() / 1e18;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Row(children: [
            Icon(Icons.arrow_back, size: 16, color: AppTheme.muted),
            SizedBox(width: 4),
            Text('返回', style: TextStyle(color: AppTheme.muted, fontSize: 14)),
          ]),
        ),
        SizedBox(height: 12),

        // ── Main card ──
        Card(child: Padding(padding: EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(m.question,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.foreground))),
              SizedBox(width: 8),
              _StatusBadge(status: m.status, isPending: isOpen && deadlinePassed),
            ]),
            SizedBox(height: 16),
            _infoGrid(m, isOpen, isResolved, deadlinePassed),
            SizedBox(height: 16),
            _poolRow(m),
            SizedBox(height: 12),
            _dualProgressBar(m),
            SizedBox(height: 8),
            Row(children: [
              _CategoryBadge(categoryId: cid),
              Spacer(),
              _CopyableId(id: m.id),
            ]),

            // ── User balance ──
            if (wallet.connected) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.background, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Text('您的余额：', style: TextStyle(fontSize: 13, color: AppTheme.muted)),
                  if (_userLoading)
                    SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5))
                  else
                    Text('${userBalance.toStringAsFixed(4)} CORN',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.foreground)),
                ]),
              ),
              if (hasShares) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Text('持仓：', style: TextStyle(fontSize: 13, color: AppTheme.muted)),
                    Text('YES ${_sharesYes.toDouble() / 1e18} ',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.yes)),
                    Text('NO ${_sharesNo.toDouble() / 1e18}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.no)),
                  ]),
                ),
              ],
            ],
          ],
        ))),
        SizedBox(height: 16),

        // ── Price chart ──
        if (_priceHistory.isNotEmpty) ...[
          _PriceChartSection(data: _priceHistory),
          SizedBox(height: 16),
        ],

        // ── Related news ──
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

        // ── Timeline ──
        _MarketTimeline(market: m),
        SizedBox(height: 16),

        // ── Trading panel ──
        if (isOpen && !deadlinePassed && wallet.connected)
          _TradingPanel(
            market: m, feeBps: _feeBps,
            userBalance: userBalance, userAllowance: userAllowance,
            rpcUrl: rpcUrl,
            onRefresh: () => _loadUserData(rpcUrl, wallet.address!, m.id),
          ),

        if (isOpen && !deadlinePassed && !wallet.connected)
          Card(child: Padding(padding: EdgeInsets.all(16), child: Column(
            children: [
              Icon(Icons.account_balance_wallet, size: 32, color: AppTheme.muted),
              SizedBox(height: 8),
              Text('请先连接钱包以进行下注',
                style: TextStyle(fontSize: 14, color: AppTheme.muted)),
            ],
          ))),

        // ── Claim reward ──
        if (isResolved && wallet.connected && hasShares && !_claimed)
          _ClaimRewardButton(marketId: m.id, rpcUrl: rpcUrl, address: wallet.address!),

        if (isResolved && wallet.connected && hasShares && _claimed)
          Card(child: Padding(padding: EdgeInsets.all(16), child: Row(children: [
            Icon(Icons.check_circle, color: AppTheme.yes, size: 20),
            SizedBox(width: 8),
            Text('奖励已领取', style: TextStyle(fontSize: 14, color: AppTheme.muted)),
          ]))),

        // ── Pending resolve ──
        if (isOpen && deadlinePassed && !canResolve)
          Card(child: Padding(padding: EdgeInsets.all(16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.hourglass_empty, color: AppTheme.primary, size: 20),
                SizedBox(width: 8),
                Text('待结算', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.foreground)),
              ]),
              SizedBox(height: 8),
              Text('截止时间已过，等待管理员结算。',
                style: TextStyle(fontSize: 14, color: AppTheme.muted)),
            ],
          ))),

        // ── Resolve buttons ──
        if (isOpen && deadlinePassed && canResolve)
          _ResolveButtons(marketId: m.id, rpcUrl: rpcUrl),

        // ── Raise dispute ──
        if (isResolved && wallet.connected)
          Padding(padding: EdgeInsets.only(top: 8), child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: Icon(Icons.warning_amber, size: 16, color: Color(0xFFD97706)),
              label: Text('发起争议', style: TextStyle(color: Color(0xFFD97706))),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Color(0xFFD97706)),
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('争议功能需要连接钱包 DApp 后操作')),
                );
              },
            ),
          )),

        // ── Related disputes ──
        if (_disputes.isNotEmpty) ...[
          SizedBox(height: 16),
          _DisputeSection(disputes: _disputes),
        ],
      ]),
    );
  }

  Widget _infoGrid(MarketData m, bool isOpen, bool isResolved, bool deadlinePassed) {
    return Column(children: [
      _infoTile('市场 ID', '#${m.id}'),
      _infoTile('截止时间', _formatDateTime(m.deadline)),
      if (isOpen && !deadlinePassed)
        Padding(padding: EdgeInsets.only(bottom: 8), child: Row(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 80, child: Text('剩余时间', style: TextStyle(color: AppTheme.muted, fontSize: 13))),
            Expanded(child: _CountdownTimer(deadline: m.deadline)),
          ],
        )),
      _infoTile('结果', isResolved ? (m.result ? 'YES 胜' : 'NO 胜') : '-'),
    ]);
  }

  Widget _infoTile(String label, String value) {
    return Padding(padding: EdgeInsets.only(bottom: 8), child: Row(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 80, child: Text(label, style: TextStyle(color: AppTheme.muted, fontSize: 13))),
        Expanded(child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.foreground))),
      ],
    ));
  }

  Widget _poolRow(MarketData m) {
    return Row(children: [
      Expanded(child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppTheme.yes.withAlpha(15), borderRadius: BorderRadius.circular(8)),
        child: Column(children: [
          Text('YES', style: TextStyle(color: AppTheme.yes, fontSize: 12, fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text('${m.outcomeYes.toStringAsFixed(2)} CORN',
            style: TextStyle(color: AppTheme.yes, fontSize: 14, fontWeight: FontWeight.bold)),
        ]),
      )),
      SizedBox(width: 12),
      Expanded(child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppTheme.no.withAlpha(15), borderRadius: BorderRadius.circular(8)),
        child: Column(children: [
          Text('NO', style: TextStyle(color: AppTheme.no, fontSize: 12, fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text('${m.outcomeNo.toStringAsFixed(2)} CORN',
            style: TextStyle(color: AppTheme.no, fontSize: 14, fontWeight: FontWeight.bold)),
        ]),
      )),
    ]);
  }

  Widget _dualProgressBar(MarketData m) {
    final yesFlex = max(1, (m.yesPct * 10).toInt());
    final noFlex = max(1, ((100 - m.yesPct) * 10).toInt());
    return ClipRRect(borderRadius: BorderRadius.circular(4), child: SizedBox(
      height: 8,
      child: Row(children: [
        Expanded(flex: yesFlex, child: Container(color: AppTheme.yes)),
        Expanded(flex: noFlex, child: Container(color: AppTheme.no)),
      ]),
    ));
  }

  String _formatDateTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Countdown Timer ───

class _CountdownTimer extends StatefulWidget {
  final int deadline;
  const _CountdownTimer({required this.deadline});

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  Timer? _timer;
  String _text = '';

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(Duration(seconds: 1), (_) => _update());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _update() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = widget.deadline - now;
    if (diff <= 0) {
      _timer?.cancel();
      if (mounted) setState(() => _text = '已截止');
      return;
    }
    final days = diff ~/ 86400;
    final hours = (diff % 86400) ~/ 3600;
    final mins = (diff % 3600) ~/ 60;
    final secs = diff % 60;
    String text = '';
    if (days > 0) text += '$days 天 ';
    if (hours > 0 || days > 0) text += '$hours 时 ';
    if (mins > 0 || hours > 0 || days > 0) text += '$mins 分 ';
    text += '$secs 秒';
    if (mounted) setState(() => _text = text);
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 6, height: 6,
        decoration: BoxDecoration(color: AppTheme.yes, shape: BoxShape.circle),
      ),
      SizedBox(width: 8),
      Text(_text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.foreground)),
    ]);
  }
}

// ─── Status Badge ───

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
      decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }
}

// ─── Category Badge ───

class _CategoryBadge extends StatelessWidget {
  final String categoryId;
  const _CategoryBadge({required this.categoryId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(12)),
      child: Text(cat.categoryLabel(categoryId), style: TextStyle(fontSize: 11, color: AppTheme.muted)),
    );
  }
}

// ─── Copyable ID ───

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
        decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(4)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('#$id', style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppTheme.muted)),
          SizedBox(width: 4),
          Icon(Icons.copy, size: 12, color: AppTheme.muted),
        ]),
      ),
    );
  }
}

// ─── Price Chart Section ───

class _PriceChartSection extends StatelessWidget {
  final List<PricePoint> data;
  const _PriceChartSection({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('价格走势', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.foreground)),
        SizedBox(height: 12),
        SizedBox(height: 150, child: CustomPaint(
          size: Size.infinite,
          painter: _ChartPainter(data: data),
        )),
        SizedBox(height: 8),
        Row(children: [
          Container(width: 12, height: 3, color: AppTheme.yes),
          SizedBox(width: 4),
          Text('YES', style: TextStyle(fontSize: 11, color: AppTheme.muted)),
          SizedBox(width: 12),
          Container(width: 12, height: 3, color: AppTheme.no),
          SizedBox(width: 4),
          Text('NO', style: TextStyle(fontSize: 11, color: AppTheme.muted)),
        ]),
      ],
    )));
  }
}

class _ChartPainter extends CustomPainter {
  final List<PricePoint> data;
  _ChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final yesPaint = Paint()
      ..color = AppTheme.yes
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final noPaint = Paint()
      ..color = AppTheme.no
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final gridPaint = Paint()
      ..color = AppTheme.border
      ..strokeWidth = 0.5;

    // Grid lines
    for (double p = 0; p <= 100; p += 25) {
      final y = size.height * (1 - p / 100);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (data.length == 1) {
      final y = size.height * (1 - data[0].yesPrice / 100);
      canvas.drawCircle(Offset(size.width / 2, y), 3, yesPaint..style = PaintingStyle.fill);
      return;
    }

    final yesPath = Path();
    final noPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = size.width * i / (data.length - 1);
      final yesY = size.height * (1 - data[i].yesPrice / 100);
      final noY = size.height * (1 - data[i].noPrice / 100);
      if (i == 0) {
        yesPath.moveTo(x, yesY);
        noPath.moveTo(x, noY);
      } else {
        yesPath.lineTo(x, yesY);
        noPath.lineTo(x, noY);
      }
    }

    canvas.drawPath(yesPath, yesPaint);
    canvas.drawPath(noPath, noPaint);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => old.data != data;
}

// ─── Market Timeline ───

class _MarketTimeline extends StatelessWidget {
  final MarketData market;
  const _MarketTimeline({required this.market});

  @override
  Widget build(BuildContext context) {
    final m = market;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final deadlinePassed = m.deadline < now;

    final events = <_TimelineEvent>[];
    events.add(_TimelineEvent(
      icon: Icons.circle, color: AppTheme.primary,
      label: '市场创建', detail: '#${m.id}',
    ));
    events.add(_TimelineEvent(
      icon: Icons.access_time, color: deadlinePassed ? AppTheme.muted : Color(0xFFCA8A04),
      label: deadlinePassed ? '已过截止' : '截止时间',
      detail: _formatTs(m.deadline),
    ));
    if (m.status == 1) {
      events.add(_TimelineEvent(
        icon: Icons.check_circle, color: AppTheme.yes,
        label: '市场结算', detail: m.result ? 'YES 胜出' : 'NO 胜出',
      ));
    } else if (m.status == 2) {
      events.add(_TimelineEvent(
        icon: Icons.cancel, color: AppTheme.muted,
        label: '市场取消', detail: '',
      ));
    }

    return Card(child: Padding(padding: EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('市场时间线', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.foreground)),
        SizedBox(height: 12),
        ...events.map((e) => _timelineItem(e)),
      ],
    )));
  }

  Widget _timelineItem(_TimelineEvent e) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Icon(e.icon, size: 16, color: e.color),
          if (e != _last) Container(width: 2, height: 24, color: AppTheme.border),
        ]),
        SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.foreground)),
            if (e.detail.isNotEmpty)
              Text(e.detail, style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          ],
        )),
      ]),
    );
  }

  _TimelineEvent get _last {
    final events = <_TimelineEvent>[];
    events.add(_TimelineEvent(icon: Icons.circle, color: AppTheme.primary, label: '', detail: ''));
    events.add(_TimelineEvent(icon: Icons.access_time, color: AppTheme.muted, label: '', detail: ''));
    if (market.status == 1 || market.status == 2) {
      events.add(_TimelineEvent(icon: Icons.check_circle, color: AppTheme.yes, label: '', detail: ''));
    }
    return events.last;
  }

  String _formatTs(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }
}

class _TimelineEvent {
  final IconData icon;
  final Color color;
  final String label;
  final String detail;
  const _TimelineEvent({required this.icon, required this.color, required this.label, required this.detail});
}

// ─── Trading Panel ───

class _TradingPanel extends ConsumerStatefulWidget {
  final MarketData market;
  final int feeBps;
  final double userBalance;
  final double userAllowance;
  final String rpcUrl;
  final VoidCallback onRefresh;

  const _TradingPanel({
    required this.market, required this.feeBps,
    required this.userBalance, required this.userAllowance,
    required this.rpcUrl, required this.onRefresh,
  });

  @override
  ConsumerState<_TradingPanel> createState() => _TradingPanelState();
}

class _TradingPanelState extends ConsumerState<_TradingPanel> {
  final _amountController = TextEditingController();
  bool _betYes = true;
  bool _pending = false;

  double get _amount => double.tryParse(_amountController.text) ?? 0;
  bool get _needsApproval => _amount > 0 && widget.userAllowance < _amount;

  Map<String, double> get _estimate {
    if (_amount <= 0) return {'profit': 0.0, 'payout': 0.0, 'odds': 1.0};
    final myPool = _betYes ? widget.market.outcomeYes : widget.market.outcomeNo;
    final oppPool = _betYes ? widget.market.outcomeNo : widget.market.outcomeYes;
    final fee = oppPool * widget.feeBps / 10000;
    final profit = (_amount * (oppPool - fee)) / (myPool + _amount);
    return {
      'profit': profit,
      'payout': _amount + profit,
      'odds': profit > 0 ? 1 + profit / _amount : 1.0,
    };
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleBet() async {
    if (_amount <= 0 || _pending) return;

    final address = ref.read(walletAddressProvider);
    if (address == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('请先连接钱包')));
      return;
    }

    setState(() => _pending = true);

    if (_needsApproval) {
      final data = ContractService.approveData(addr.predictionMarketAddress, BigInt.from((_amount * 1e18).toInt()));
      _showRawTx('授权 CORN', addr.cornTokenAddress, data);
    } else {
      final data = ContractService.betData(widget.market.id, _betYes ? 0 : 1, BigInt.from((_amount * 1e18).toInt()));
      _showRawTx('下注 ${_betYes ? "YES" : "NO"}', addr.predictionMarketAddress, data);
    }

    setState(() => _pending = false);
  }

  void _showRawTx(String title, String to, String data) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(title, style: TextStyle(fontSize: 16)),
      content: SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, children: [
          Text('合约：', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          SelectableText(to, style: TextStyle(fontSize: 11, fontFamily: 'monospace')),
          SizedBox(height: 8),
          Text('交易数据：', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          SelectableText(data, style: TextStyle(fontSize: 10, fontFamily: 'monospace')),
          SizedBox(height: 8),
          Text('请将以上数据用于钱包签名和广播。',
            style: TextStyle(fontSize: 11, color: AppTheme.muted)),
        ],
      )),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('关闭')),
        TextButton(onPressed: () {
          Clipboard.setData(ClipboardData(text: 'to:$to\ndata:$data'));
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已复制')));
        }, child: Text('复制')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.market;
    final yesPct = m.yesPct;
    final noPct = 100 - yesPct;
    final est = _estimate;

    return Card(child: Padding(padding: EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('下注', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.foreground)),
        SizedBox(height: 12),

        // YES/NO toggle
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => setState(() => _betYes = true),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _betYes ? AppTheme.yes : AppTheme.card,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
                border: Border.all(color: _betYes ? AppTheme.yes : AppTheme.border),
              ),
              child: Center(child: Text('YES ${yesPct.toStringAsFixed(0)}%',
                style: TextStyle(color: _betYes ? Colors.white : AppTheme.foreground,
                  fontWeight: FontWeight.bold, fontSize: 14))),
            ),
          )),
          Expanded(child: GestureDetector(
            onTap: () => setState(() => _betYes = false),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: !_betYes ? AppTheme.no : AppTheme.card,
                borderRadius: BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
                border: Border.all(color: !_betYes ? AppTheme.no : AppTheme.border),
              ),
              child: Center(child: Text('NO ${noPct.toStringAsFixed(0)}%',
                style: TextStyle(color: !_betYes ? Colors.white : AppTheme.foreground,
                  fontWeight: FontWeight.bold, fontSize: 14))),
            ),
          )),
        ]),
        SizedBox(height: 12),

        // Amount input
        Row(children: [
          Expanded(child: TextField(
            controller: _amountController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: '数量（CORN）'),
          )),
          SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => _amountController.text = widget.userBalance.toStringAsFixed(2),
            style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
            child: Text('最大', style: TextStyle(fontSize: 12)),
          ),
        ]),
        SizedBox(height: 4),
        Text('余额：${widget.userBalance.toStringAsFixed(4)} CORN',
          style: TextStyle(fontSize: 11, color: AppTheme.muted)),
        SizedBox(height: 8),

        // Quick buttons
        Row(children: ['10', '50', '100'].map((amt) {
          return Padding(padding: EdgeInsets.only(right: 8), child: OutlinedButton(
            onPressed: () { _amountController.text = amt; setState(() {}); },
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle: TextStyle(fontSize: 12),
            ),
            child: Text(amt),
          ));
        }).toList()),
        SizedBox(height: 12),

        // Estimated payout
        if (_amount > 0) Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.background, borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _estRow('预估收益', '${est['profit']!.toStringAsFixed(4)} CORN', AppTheme.yes),
            SizedBox(height: 4),
            _estRow('预计回收', '${est['payout']!.toStringAsFixed(4)} CORN', AppTheme.foreground),
            SizedBox(height: 4),
            _estRow('隐含赔率', '${est['odds']!.toStringAsFixed(2)}x', AppTheme.primary),
            SizedBox(height: 8),
            Text('赢家获得对手资金池（扣除 ${widget.feeBps / 100}% 平台费）',
              style: TextStyle(fontSize: 10, color: AppTheme.muted)),
          ]),
        ),
        SizedBox(height: 12),

        // Bet button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _betYes ? AppTheme.yes : AppTheme.no,
              padding: EdgeInsets.symmetric(vertical: 12),
              disabledBackgroundColor: AppTheme.muted.withAlpha(60),
            ),
            onPressed: _pending || _amount <= 0 ? null : _handleBet,
            child: _pending
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(
                    _needsApproval ? '授权并下注' : '下注 ${_betYes ? "YES" : "NO"}',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
          ),
        ),
      ],
    )));
  }

  Widget _estRow(String label, String value, Color valueColor) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 12, color: AppTheme.muted)),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: valueColor)),
    ]);
  }
}

// ─── Claim Reward Button ───

class _ClaimRewardButton extends StatefulWidget {
  final int marketId;
  final String rpcUrl;
  final String address;
  const _ClaimRewardButton({required this.marketId, required this.rpcUrl, required this.address});

  @override
  State<_ClaimRewardButton> createState() => _ClaimRewardButtonState();
}

class _ClaimRewardButtonState extends State<_ClaimRewardButton> {
  bool _pending = false;

  Future<void> _handleClaim() async {
    if (_pending) return;
    setState(() => _pending = true);
    final data = ContractService.claimRewardData(widget.marketId);
    if (!mounted) return;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('领取奖励', style: TextStyle(fontSize: 16)),
      content: SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('合约：', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          SelectableText(addr.predictionMarketAddress, style: TextStyle(fontSize: 11, fontFamily: 'monospace')),
          SizedBox(height: 8),
          Text('交易数据：', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          SelectableText(data, style: TextStyle(fontSize: 10, fontFamily: 'monospace')),
        ],
      )),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('关闭')),
        TextButton(onPressed: () {
          Clipboard.setData(ClipboardData(text: 'to:${addr.predictionMarketAddress}\ndata:$data'));
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已复制')));
        }, child: Text('复制')),
      ],
    ));
    setState(() => _pending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, padding: EdgeInsets.symmetric(vertical: 12)),
          onPressed: _pending ? null : _handleClaim,
          child: _pending
              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('领取奖励', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

// ─── Resolve Buttons ───

class _ResolveButtons extends StatefulWidget {
  final int marketId;
  final String rpcUrl;
  const _ResolveButtons({required this.marketId, required this.rpcUrl});

  @override
  State<_ResolveButtons> createState() => _ResolveButtonsState();
}

class _ResolveButtonsState extends State<_ResolveButtons> {
  bool _pending = false;

  void _showRawTx(bool result) {
    final data = ContractService.resolveMarketData(widget.marketId, result);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('结算市场', style: TextStyle(fontSize: 16)),
      content: SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('结果：${result ? "YES 胜" : "NO 胜"}',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.foreground)),
          SizedBox(height: 8),
          Text('合约：', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          SelectableText(addr.predictionMarketAddress, style: TextStyle(fontSize: 11, fontFamily: 'monospace')),
          SizedBox(height: 8),
          Text('交易数据：', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          SelectableText(data, style: TextStyle(fontSize: 10, fontFamily: 'monospace')),
        ],
      )),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('关闭')),
        TextButton(onPressed: () {
          Clipboard.setData(ClipboardData(text: 'to:${addr.predictionMarketAddress}\ndata:$data'));
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已复制')));
        }, child: Text('复制')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.gavel, color: AppTheme.primary, size: 20),
          SizedBox(width: 8),
          Text('结算市场', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.foreground)),
        ]),
        SizedBox(height: 8),
        Text('截止时间已过，请选择获胜结果。',
          style: TextStyle(fontSize: 14, color: AppTheme.muted)),
        SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: _pending ? null : () => _showRawTx(true),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 10),
              side: BorderSide(color: AppTheme.yes),
            ),
            child: _pending
                ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('结算 YES 胜', style: TextStyle(color: AppTheme.yes)),
          )),
          SizedBox(width: 12),
          Expanded(child: OutlinedButton(
            onPressed: _pending ? null : () => _showRawTx(false),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 10),
              side: BorderSide(color: AppTheme.no),
            ),
            child: _pending
                ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('结算 NO 胜', style: TextStyle(color: AppTheme.no)),
          )),
        ]),
      ],
    )));
  }
}

// ─── Dispute Section ───

class _DisputeSection extends StatelessWidget {
  final List<DisputeData> disputes;
  const _DisputeSection({required this.disputes});

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('关联争议', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.foreground)),
        SizedBox(height: 12),
        ...disputes.map(_disputeItem),
      ],
    )));
  }

  Widget _disputeItem(DisputeData d) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('#${d.id}', style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppTheme.muted)),
          SizedBox(width: 8),
          _DisputeStateBadge(state: d.state),
          SizedBox(width: 8),
          Text(d.typeLabel, style: TextStyle(fontSize: 11, color: AppTheme.muted)),
          Spacer(),
          Text('${(d.deposit.toDouble() / 1e18).toStringAsFixed(2)} CORN',
            style: TextStyle(fontSize: 11, color: AppTheme.muted)),
        ]),
        if (d.votesFor + d.votesAgainst > BigInt.zero) ...[
          SizedBox(height: 8),
          Row(children: [
            Text('${d.votesFor} 赞成', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.yes)),
            SizedBox(width: 8),
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: SizedBox(
              height: 6,
              child: Row(children: [
                Expanded(flex: max(1, (d.yesPct * 10).toInt()), child: Container(color: AppTheme.yes)),
                Expanded(flex: max(1, ((100 - d.yesPct) * 10).toInt()), child: Container(color: AppTheme.no)),
              ]),
            ))),
            SizedBox(width: 8),
            Text('${d.votesAgainst} 反对', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.no)),
          ]),
        ],
      ]),
    );
  }
}

class _DisputeStateBadge extends StatelessWidget {
  final int state;
  const _DisputeStateBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final label = state == 0 ? '进行中' : state == 1 ? '已通过' : '已驳回';
    final color = state == 1 ? AppTheme.yes : state == 2 ? AppTheme.no : AppTheme.primary;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
    );
  }
}
