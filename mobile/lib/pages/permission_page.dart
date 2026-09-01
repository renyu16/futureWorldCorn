import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:future_world_corn_mobile/providers/wallet_provider.dart';
import 'package:future_world_corn_mobile/providers/rpc_provider.dart';
import 'package:future_world_corn_mobile/services/contract_service.dart';
import 'package:future_world_corn_mobile/contracts/addresses.dart' as addr;
import 'package:future_world_corn_mobile/theme/app_theme.dart';

class PermissionPage extends ConsumerStatefulWidget {
  const PermissionPage({super.key});
  @override
  ConsumerState<PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends ConsumerState<PermissionPage> {
  final _addrCtrl = TextEditingController();
  bool _loading = true;
  bool _isOwner = false;
  String ownerAddress = '';
  String? _queryResult; // 'yes' | 'no' | error text
  bool _querying = false;
  String? _queryAddr;

  @override
  void initState() {
    super.initState();
    _loadOwner();
  }

  Future<void> _loadOwner() async {
    final rpc = ref.read(rpcUrlProvider);
    final wallet = ref.read(walletProvider);
    try {
      final owner = await ContractService.marketOwner(rpc);
      final isOwner = wallet.connected && wallet.address!.toLowerCase() == owner.toLowerCase();
      if (mounted) {
        setState(() {
          _isOwner = isOwner;
          ownerAddress = owner;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  void dispose() {
    _addrCtrl.dispose();
    super.dispose();
  }

  Future<void> _query() async {
    final addrText = _addrCtrl.text.trim();
    if (addrText.length != 42 || !addrText.startsWith('0x')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效的 0x 地址')));
      return;
    }
    setState(() { _querying = true; _queryResult = null; _queryAddr = addrText; });
    final rpc = ref.read(rpcUrlProvider);
    try {
      final yes = await ContractService.isMarketCreator(rpc, addrText);
      if (mounted) setState(() { _querying = false; _queryResult = yes ? 'yes' : 'no'; });
    } catch (_) {
      if (mounted) setState(() { _querying = false; _queryResult = 'err'; });
    }
  }

  void _showRawTx(String title, String to, String data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('合约：', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
              SelectableText(to, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              Text('交易数据：', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
              SelectableText(data, style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              const Text('请将以上数据用于钱包签名和广播。', style: TextStyle(fontSize: 11, color: AppTheme.muted)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: 'to:$to\ndata:$data'));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制')));
            },
            child: const Text('复制'),
          ),
        ],
      ),
    );
  }

  void _grant() {
    final addrText = _addrCtrl.text.trim();
    if (addrText.length != 42 || !addrText.startsWith('0x')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效的 0x 地址')));
      return;
    }
    final data = ContractService.setMarketCreatorData(addrText, true);
    _showRawTx('授权创建市场', addr.predictionMarketAddress, data);
  }

  void _revoke() {
    final addrText = _addrCtrl.text.trim();
    if (addrText.length != 42 || !addrText.startsWith('0x')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效的 0x 地址')));
      return;
    }
    final data = ContractService.setMarketCreatorData(addrText, false);
    _showRawTx('撤销创建市场权限', addr.predictionMarketAddress, data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('创建权限管理', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppTheme.border),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Owner banner
                Card(
                  color: AppTheme.card,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _isOwner
                        ? const Row(children: [
                            Icon(Icons.admin_panel_settings, size: 16, color: AppTheme.yes),
                            SizedBox(width: 6),
                            Text('当前钱包是 Owner，可授权/撤销创建权限', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                          ])
                        : const Row(children: [
                            Icon(Icons.warning, size: 16, color: Color(0xFFF59E0B)),
                            SizedBox(width: 6),
                            Expanded(child: Text('当前钱包不是 Owner，仅可查询地址授权状态', style: TextStyle(fontSize: 12, color: AppTheme.muted))),
                          ]),
                  ),
                ),
                if (_isOwner) ...[
                  const SizedBox(height: 8),
                  Text('Owner: $ownerAddress', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.muted)),
                ],
                const SizedBox(height: 16),

                Card(
                  color: AppTheme.card,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('目标地址', style: TextStyle(fontSize: 13, color: AppTheme.muted)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _addrCtrl,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          decoration: const InputDecoration(hintText: '0x...  查询/授权的 creator 地址'),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _querying ? null : _query,
                            child: _querying ? const Text('查询中...') : const Text('查询该地址是否已授权'),
                          ),
                        ),
                        if (_queryResult != null) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _queryResult == 'yes'
                                  ? '$_queryAddr 已授权（marketCreator）'
                                  : _queryResult == 'no'
                                      ? '$_queryAddr 未授权'
                                      : '查询失败，请检查网络',
                              style: TextStyle(
                                fontSize: 12,
                                color: _queryResult == 'yes'
                                    ? AppTheme.yes
                                    : _queryResult == 'no'
                                        ? Color(0xFFEF4444)
                                        : Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                        ],
                        if (_isOwner) ...[
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _grant,
                                child: const Text('授权'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(foregroundColor: Color(0xFFEF4444)),
                                onPressed: _revoke,
                                child: const Text('撤销'),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          const Text('授权/撤销通过 Owner 钱包签名上链，一次授权长期有效。',
                              style: TextStyle(fontSize: 11, color: AppTheme.muted)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}