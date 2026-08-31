import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:future_world_corn_mobile/providers/wallet_provider.dart';
import 'package:future_world_corn_mobile/providers/rpc_provider.dart';
import 'package:future_world_corn_mobile/services/contract_service.dart';
import 'package:future_world_corn_mobile/contracts/addresses.dart' as addr;
import 'package:future_world_corn_mobile/theme/app_theme.dart';

class CreateMarketPage extends ConsumerStatefulWidget {
  const CreateMarketPage({super.key});
  @override
  ConsumerState<CreateMarketPage> createState() => _CreateMarketPageState();
}

class _CreateMarketPageState extends ConsumerState<CreateMarketPage> {
  final _questionCtrl = TextEditingController();
  final _deadlineDateCtrl = TextEditingController();
  final _deadlineTimeCtrl = TextEditingController();
  final _feeBpsCtrl = TextEditingController();
  DateTime? _deadlineDate;
  TimeOfDay? _deadlineTime;
  bool _loadingPerm = true;
  bool _isOwner = false;
  bool _isCreator = false;
  int _defaultFee = 200;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPermission();
  }

  Future<void> _loadPermission() async {
    final rpc = ref.read(rpcUrlProvider);
    final wallet = ref.read(walletProvider);
    if (!wallet.connected) {
      setState(() { _loadingPerm = false; _error = '请先在设置中连接钱包'; });
      return;
    }
    try {
      final owner = await ContractService.marketOwner(rpc);
      final creator = await ContractService.isMarketCreator(rpc, wallet.address!);
      final fee = await ContractService.defaultFeeBps(rpc);
      if (mounted) {
        setState(() {
          _isOwner = wallet.address!.toLowerCase() == owner.toLowerCase();
          _isCreator = creator;
          _defaultFee = fee;
          _loadingPerm = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingPerm = false;
          _error = '权限检查失败（网络错误）';
        });
      }
    }
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    _deadlineDateCtrl.dispose();
    _deadlineTimeCtrl.dispose();
    _feeBpsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _deadlineDate ?? now.add(const Duration(days: 1)),
      firstDate: now.add(const Duration(minutes: 5)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (date != null) {
      setState(() {
        _deadlineDate = date;
        _deadlineDateCtrl.text = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _deadlineTime ?? const TimeOfDay(hour: 23, minute: 59),
    );
    if (time != null) {
      setState(() {
        _deadlineTime = time;
        _deadlineTimeCtrl.text = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  void _showRawTx(String to, String data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('创建市场', style: TextStyle(fontSize: 16)),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
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

  void _handleCreate() {
    if (!_isOwner && !_isCreator) return;

    final question = _questionCtrl.text.trim();
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入问题')));
      return;
    }

    if (_deadlineDate == null || _deadlineTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请选择截止日期和时间')));
      return;
    }

    final deadline = DateTime(
      _deadlineDate!.year,
      _deadlineDate!.month,
      _deadlineDate!.day,
      _deadlineTime!.hour,
      _deadlineTime!.minute,
    );
    final deadlineUnix = deadline.millisecondsSinceEpoch ~/ 1000;
    if (deadlineUnix <= DateTime.now().millisecondsSinceEpoch ~/ 1000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('截止时间必须晚于当前时间')));
      return;
    }

    final feeBpsStr = _feeBpsCtrl.text.trim();
    final feeBps = feeBpsStr.isEmpty ? 0 : int.tryParse(feeBpsStr) ?? 0;
    if (feeBps < 0 || feeBps > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('费率需在 0-1000 之间')));
      return;
    }

    final data = ContractService.createMarketData(question, deadlineUnix, feeBps);
    _showRawTx(addr.predictionMarketAddress, data);
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('创建市场', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppTheme.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // permission banner
          if (_loadingPerm)
            Card(
              color: AppTheme.card,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('正在检查权限...', style: TextStyle(color: AppTheme.muted)),
              ),
            )
          else if (_error != null)
            Card(
              color: AppTheme.card,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: const TextStyle(color: Color(0xFFEF4444))),
              ),
            )
          else if (_isOwner || _isCreator)
            Card(
              color: AppTheme.card,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const Icon(Icons.check_circle, size: 14, color: AppTheme.yes),
                  const SizedBox(width: 6),
                  Text(
                    _isOwner ? '当前地址为 Owner，可创建市场' : '当前地址已授权 marketCreator',
                    style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                  ),
                ]),
              ),
            )
          else
            Card(
              color: AppTheme.card,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Row(children: [
                  Icon(Icons.warning, size: 14, color: Color(0xFFF59E0B)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text('当前地址没有创建市场权限，请联系 Owner 添加 marketCreator 白名单。',
                        style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                  ),
                ]),
              ),
            ),
          const SizedBox(height: 16),

          Card(
            color: AppTheme.card,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question
                  Text('问题', style: TextStyle(fontSize: 13, color: AppTheme.muted)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _questionCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: r'例如：ETH 在 2026 年底前会突破 $10k 吗？',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Deadline
                  Text('截止时间', style: TextStyle(fontSize: 13, color: AppTheme.muted)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _deadlineDateCtrl,
                          readOnly: true,
                          onTap: _pickDate,
                          decoration: const InputDecoration(hintText: '日期', suffixIcon: Icon(Icons.calendar_today, size: 16)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _deadlineTimeCtrl,
                          readOnly: true,
                          onTap: _pickTime,
                          decoration: const InputDecoration(hintText: '时间', suffixIcon: Icon(Icons.access_time, size: 16)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Fee
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _feeBpsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '费率（基点，留空使用默认 $_defaultFee）',
                        ),
                      ),
                    ),
                  ]),
                  Text('0 = 使用默认费率 ($_defaultFee bps)；最大 1000（10%）',
                      style: TextStyle(fontSize: 11, color: AppTheme.muted)),
                  const SizedBox(height: 20),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: wallet.connected ? _handleCreate : null,
                      child: const Text('构造交易'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}