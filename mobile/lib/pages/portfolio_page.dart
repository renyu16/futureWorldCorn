import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:future_world_corn_mobile/providers/wallet_provider.dart';
import 'package:future_world_corn_mobile/providers/rpc_provider.dart';
import 'package:future_world_corn_mobile/providers/market_provider.dart';
import 'package:future_world_corn_mobile/services/contract_service.dart';
import 'package:future_world_corn_mobile/theme/app_theme.dart';

class PortfolioPage extends ConsumerStatefulWidget {
  const PortfolioPage({super.key});
  @override
  ConsumerState<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends ConsumerState<PortfolioPage> {
  List<_Position> _positions = [];
  bool _loading = false;
  BigInt _cornBalance = BigInt.zero;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final wallet = ref.read(walletProvider);
    if (!wallet.connected) return;
    final rpcUrl = ref.read(rpcUrlProvider);
    final address = wallet.address!;
    setState(() => _loading = true);

    try {
      final balance = await ContractService.tokenBalance(rpcUrl, address);
      final marketsAsync = ref.read(marketsProvider);
      final markets = await Future.value(marketsAsync.valueOrNull ?? []);

      final positions = <_Position>[];
      for (final m in markets) {
        final sharesYes = await ContractService.userSharesYes(rpcUrl, m.id, address);
        final sharesNo = await ContractService.userSharesNo(rpcUrl, m.id, address);
        if (sharesYes > BigInt.zero || sharesNo > BigInt.zero) {
          positions.add(_Position(
            market: m, sharesYes: sharesYes, sharesNo: sharesNo,
          ));
        }
      }

      if (mounted) {
        setState(() {
          _cornBalance = balance;
          _positions = positions;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('投资组合', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppTheme.border),
        ),
      ),
      body: !wallet.connected
          ? _buildNoWallet()
          : _loading
              ? _buildLoading()
              : _buildBody(wallet),
    );
  }

  Widget _buildNoWallet() {
    return Center(child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.account_balance_wallet, size: 48, color: AppTheme.muted.withAlpha(80)),
        SizedBox(height: 12),
        Text('请先在设置中连接钱包', style: TextStyle(color: AppTheme.muted)),
      ],
    ));
  }

  Widget _buildLoading() {
    return Center(child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
        SizedBox(height: 12),
        Text('正在加载持仓...', style: TextStyle(color: AppTheme.muted)),
      ],
    ));
  }

  Widget _buildBody(WalletState wallet) {
    final active = _positions.where((p) => p.market.status == 0).toList();
    final resolved = _positions.where((p) => p.market.status == 1).toList();
    final totalShares = _positions.fold<BigInt>(BigInt.zero, (sum, p) => sum + p.sharesYes + p.sharesNo);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Summary card
          Card(child: Padding(padding: EdgeInsets.all(16), child: Column(
            children: [
              _summaryRow('钱包', '${wallet.address!.substring(0, 6)}...${wallet.address!.substring(38)}'),
              _summaryRow('CORN 余额', '${(_cornBalance.toDouble() / 1e18).toStringAsFixed(4)} CORN'),
              _summaryRow('持仓市场', '${_positions.length}'),
              _summaryRow('总份额', totalShares > BigInt.zero ? '${(totalShares.toDouble() / 1e18).toStringAsFixed(4)}' : '0'),
            ],
          ))),
          SizedBox(height: 16),

          if (active.isNotEmpty) ...[
            Text('进行中 (${active.length})', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.muted)),
            SizedBox(height: 8),
            ...active.map((p) => Padding(padding: EdgeInsets.only(bottom: 12), child: _PositionCard(position: p))),
          ],

          if (resolved.isNotEmpty) ...[
            Text('已结算 (${resolved.length})', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.muted)),
            SizedBox(height: 8),
            ...resolved.map((p) => Padding(padding: EdgeInsets.only(bottom: 12), child: _PositionCard(position: p))),
          ],

          if (_positions.isEmpty)
            Padding(padding: EdgeInsets.symmetric(vertical: 48), child: Center(child: Column(
              children: [
                Icon(Icons.inbox_outlined, size: 48, color: AppTheme.muted.withAlpha(80)),
                SizedBox(height: 12),
                Text('暂无持仓', style: TextStyle(color: AppTheme.muted)),
                SizedBox(height: 4),
                Text('参与市场预测后，您的持仓将显示在这里', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
              ],
            ))),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(padding: EdgeInsets.only(bottom: 8), child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: AppTheme.muted)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.foreground)),
      ],
    ));
  }
}

class _Position {
  final MarketData market;
  final BigInt sharesYes;
  final BigInt sharesNo;
  _Position({required this.market, required this.sharesYes, required this.sharesNo});
  BigInt get totalShares => sharesYes + sharesNo;
}

class _PositionCard extends StatelessWidget {
  final _Position position;
  const _PositionCard({required this.position});

  @override
  Widget build(BuildContext context) {
    final p = position;
    final m = p.market;
    final total = p.totalShares.toDouble() / 1e18;
    final yesAmt = p.sharesYes.toDouble() / 1e18;
    final noAmt = p.sharesNo.toDouble() / 1e18;
    final yesPct = m.outcomeYes > 0 ? (p.sharesYes.toDouble() / 1e18 / m.outcomeYes * 100) : 0.0;
    final noPct = m.outcomeNo > 0 ? (p.sharesNo.toDouble() / 1e18 / m.outcomeNo * 100) : 0.0;
    final statusLabel = m.status == 1 ? '已结算' : m.status == 2 ? '已取消' : '进行中';
    final canClaim = m.status == 1 && p.totalShares > BigInt.zero;

    return Card(child: Padding(padding: EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(m.question,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.foreground),
            maxLines: 2, overflow: TextOverflow.ellipsis)),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (m.status == 1 ? AppTheme.yes : AppTheme.primary).withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(statusLabel, style: TextStyle(fontSize: 11,
              color: m.status == 1 ? AppTheme.yes : AppTheme.primary, fontWeight: FontWeight.w500)),
          ),
        ]),
        SizedBox(height: 12),
        _shareRow('YES', yesAmt, yesPct, AppTheme.yes),
        SizedBox(height: 8),
        _shareRow('NO', noAmt, noPct, AppTheme.no),
        SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('持仓: ${total > 0 ? "${total.toStringAsFixed(4)} 份额" : "无"}',
            style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          if (m.status == 1)
            Text('结果: ${m.result ? "YES 胜" : "NO 胜"}',
              style: TextStyle(fontSize: 12, color: m.result ? AppTheme.yes : AppTheme.no)),
        ]),
        if (canClaim) ...[
          SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('请使用钱包签名领取奖励')),
              );
            },
            child: Text('领取奖励'),
          )),
        ],
      ],
    )));
  }

  Widget _shareRow(String label, double amount, double pct, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 12, color: AppTheme.muted)),
        Text(amount > 0 ? '${pct.toStringAsFixed(1)}%' : '-', style: TextStyle(fontSize: 12, fontFamily: 'monospace')),
      ]),
      SizedBox(height: 4),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: SizedBox(
        height: 6,
        child: LinearProgressIndicator(value: (pct / 100).clamp(0, 1), backgroundColor: AppTheme.border, valueColor: AlwaysStoppedAnimation(color)),
      )),
    ]);
  }
}
