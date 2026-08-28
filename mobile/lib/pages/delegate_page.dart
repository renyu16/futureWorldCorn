import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:future_world_corn_mobile/providers/wallet_provider.dart';
import 'package:future_world_corn_mobile/providers/rpc_provider.dart';
import 'package:future_world_corn_mobile/services/contract_service.dart';
import 'package:future_world_corn_mobile/contracts/addresses.dart' as addr;
import 'package:future_world_corn_mobile/theme/app_theme.dart';

class DelegatePage extends ConsumerStatefulWidget {
  const DelegatePage({super.key});
  @override
  ConsumerState<DelegatePage> createState() => _DelegatePageState();
}

class _DelegatePageState extends ConsumerState<DelegatePage> {
  BigInt _cornBalance = BigInt.zero;
  BigInt _govCornBalance = BigInt.zero;
  BigInt _votes = BigInt.zero;

  String _delegateTarget = '';
  bool _loading = false;
  bool _pending = false;

  final _depositController = TextEditingController();
  final _withdrawController = TextEditingController();
  final _delegateeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _depositController.dispose();
    _withdrawController.dispose();
    _delegateeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final wallet = ref.read(walletProvider);
    if (!wallet.connected) return;
    final rpcUrl = ref.read(rpcUrlProvider);
    final address = wallet.address!;
    setState(() => _loading = true);

    try {
      final results = await Future.wait([
        ContractService.tokenBalance(rpcUrl, address),
        ContractService.govCornBalance(rpcUrl, address),
        ContractService.govCornVotes(rpcUrl, address),
        ContractService.govCornDelegates(rpcUrl, address),
      ]);
      if (mounted) {
        setState(() {
          _cornBalance = results[0] as BigInt;
          _govCornBalance = results[1] as BigInt;
          _votes = results[2] as BigInt;
          _delegateTarget = results[3] as String;
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
        title: Text('委托', style: TextStyle(fontWeight: FontWeight.bold)),
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
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.how_to_vote, size: 48, color: AppTheme.muted.withAlpha(80)),
      SizedBox(height: 12),
      Text('请先在设置中连接钱包', style: TextStyle(color: AppTheme.muted)),
    ]));
  }

  Widget _buildLoading() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
      SizedBox(height: 12),
      Text('正在加载...', style: TextStyle(color: AppTheme.muted)),
    ]));
  }

  Widget _buildBody(WalletState wallet) {
    final cornAmt = _cornBalance.toDouble() / 1e18;
    final govAmt = _govCornBalance.toDouble() / 1e18;
    final votesAmt = _votes.toDouble() / 1e18;
    final isSelfDelegated = _delegateTarget.isNotEmpty &&
        _delegateTarget.toLowerCase() == wallet.address!.toLowerCase();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: EdgeInsets.all(16), children: [
        // Balance summary
        Card(child: Padding(padding: EdgeInsets.all(16), child: Row(
          children: [
            _balanceItem('CORN', cornAmt),
            _balanceItem('govCORN', govAmt),
            _balanceItem('投票权', votesAmt),
          ],
        ))),
        SizedBox(height: 16),

        // Current delegation
        Card(child: Padding(padding: EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前委托', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            if (_delegateTarget.isNotEmpty && _delegateTarget != '0x0000000000000000000000000000000000000000')
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('委托目标', style: TextStyle(fontSize: 11, color: AppTheme.muted)),
                    SizedBox(height: 2),
                    Text('${_delegateTarget.substring(0, 6)}...${_delegateTarget.substring(38)}',
                      style: TextStyle(fontSize: 12, fontFamily: 'monospace')),
                  ]),
                ]),
              )
            else
              Text('未委托', style: TextStyle(color: AppTheme.muted)),
            if (isSelfDelegated)
              Padding(padding: EdgeInsets.only(top: 8), child: Text(
                '当前为自我委托（默认状态），委托给他人后投票权将转移。',
                style: TextStyle(fontSize: 12, color: AppTheme.muted)),
              ),
          ],
        ))),
        SizedBox(height: 16),

        // Deposit
        _formCard(
          title: 'Deposit CORN → govCORN',
          children: [
            TextField(controller: _depositController, keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(hintText: '数量')),
            SizedBox(height: 8),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: _pending ? null : () => _showRawTx('授权 CORN', addr.cornTokenAddress,
                  ContractService.approveData(addr.govCornTokenAddress, _parseAmount(_depositController.text))),
                child: Text('授权'),
              )),
              SizedBox(width: 8),
              Expanded(child: ElevatedButton(
                onPressed: _pending ? null : () => _showRawTx('存入 govCORN', addr.govCornTokenAddress,
                  ContractService.depositForData(wallet.address!, _parseAmount(_depositController.text))),
                child: Text('存入'),
              )),
            ]),
          ],
        ),
        SizedBox(height: 16),

        // Withdraw
        _formCard(
          title: 'Withdraw govCORN → CORN',
          children: [
            TextField(controller: _withdrawController, keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(hintText: '数量')),
            SizedBox(height: 8),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _pending ? null : () => _showRawTx('取回 CORN', addr.govCornTokenAddress,
                ContractService.withdrawToData(wallet.address!, _parseAmount(_withdrawController.text))),
              child: Text('取回'),
            )),
          ],
        ),
        SizedBox(height: 16),

        // Delegate
        _formCard(
          title: '委托投票权',
          children: [
            TextField(controller: _delegateeController, decoration: InputDecoration(hintText: '被委托人地址 0x...')),
            SizedBox(height: 8),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _pending ? null : () => _showRawTx('委托投票权', addr.govCornTokenAddress,
                ContractService.delegateData(_delegateeController.text.trim())),
              child: Text('委托'),
            )),
          ],
        ),
      ]),
    );
  }

  Widget _balanceItem(String label, double amount) {
    return Expanded(child: Column(children: [
      Text(label, style: TextStyle(fontSize: 11, color: AppTheme.muted)),
      SizedBox(height: 4),
      Text(amount.toStringAsFixed(4), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.foreground)),
    ]));
  }

  Widget _formCard({required String title, required List<Widget> children}) {
    return Card(child: Padding(padding: EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        SizedBox(height: 12),
        ...children,
      ],
    )));
  }

  BigInt _parseAmount(String text) {
    final val = double.tryParse(text) ?? 0;
    return BigInt.from(val * 1e18);
  }

  void _showRawTx(String title, String to, String data) {
    if (data.startsWith('propose')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('请输入有效数据')));
      return;
    }
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(title, style: TextStyle(fontSize: 16)),
      content: SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('合约：', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          SelectableText(to, style: TextStyle(fontSize: 11, fontFamily: 'monospace')),
          SizedBox(height: 8),
          Text('交易数据：', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          SelectableText(data, style: TextStyle(fontSize: 10, fontFamily: 'monospace')),
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
}
