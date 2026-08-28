import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:future_world_corn_mobile/providers/rpc_provider.dart';
import 'package:future_world_corn_mobile/services/contract_service.dart';
import 'package:future_world_corn_mobile/services/dispute_service.dart';
import 'package:future_world_corn_mobile/contracts/addresses.dart' as addr;
import 'package:future_world_corn_mobile/theme/app_theme.dart';

const _disputeTypes = ['预言机结果', '市场内容'];
const _disputeStates = ['进行中', '已通过', '已驳回'];
const _stateColors = [AppTheme.primary, AppTheme.yes, AppTheme.no];

class HumanHousePage extends ConsumerStatefulWidget {
  const HumanHousePage({super.key});
  @override
  ConsumerState<HumanHousePage> createState() => _HumanHousePageState();
}

class _HumanHousePageState extends ConsumerState<HumanHousePage> {
  List<DisputeData> _disputes = [];
  bool _loading = false;
  String? _error;
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rpcUrl = ref.read(rpcUrlProvider);
    setState(() { _loading = true; _error = null; });
    try {
      final count = await ContractService.disputeCount(rpcUrl);
      final disputes = <DisputeData>[];
      for (int i = 1; i <= count; i++) {
        final data = await ContractService.getDispute(rpcUrl, i);
        if (data != null) {
          disputes.add(DisputeData(
            id: i, marketId: data['marketId'] as int,
            disputeType: data['disputeType'] as int,
            state: data['state'] as int,
            deposit: data['deposit'] as BigInt,
            deadline: data['deadline'] as int,
            votesFor: data['votesFor'] as BigInt,
            votesAgainst: data['votesAgainst'] as BigInt,
          ));
        }
      }
      if (mounted) setState(() { _disputes = disputes.reversed.toList(); _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '争议加载失败'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedId != null) {
      return _DisputeDetailPage(disputeId: _selectedId!, onBack: () => setState(() => _selectedId = null));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('HumanHouse 争议', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(preferredSize: Size.fromHeight(0.5), child: Container(height: 0.5, color: AppTheme.border)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: EdgeInsets.all(16), children: [
          _RaiseDisputeCard(onCreated: _load),
          SizedBox(height: 16),
          if (_loading)
            Center(child: Text('加载争议...', style: TextStyle(color: AppTheme.muted)))
          else if (_error != null)
            Center(child: Text(_error!, style: TextStyle(color: AppTheme.no)))
          else if (_disputes.isEmpty)
            Center(child: Padding(padding: EdgeInsets.all(32), child: Text('暂无争议', style: TextStyle(color: AppTheme.muted))))
          else
            ..._disputes.map((d) => Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _DisputeRow(dispute: d, onSelect: () => setState(() => _selectedId = d.id)),
            )),
        ]),
      ),
    );
  }
}

class _RaiseDisputeCard extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _RaiseDisputeCard({required this.onCreated});

  @override
  ConsumerState<_RaiseDisputeCard> createState() => _RaiseDisputeCardState();
}

class _RaiseDisputeCardState extends ConsumerState<_RaiseDisputeCard> {
  final _marketIdController = TextEditingController();
  final _reasonController = TextEditingController();
  int _disputeType = 0;
  BigInt _deposit = BigInt.zero;

  @override
  void initState() {
    super.initState();
    _loadDeposit();
  }

  Future<void> _loadDeposit() async {
    final rpcUrl = ref.read(rpcUrlProvider);
    try {
      final deposit = await ContractService.disputeDeposit(rpcUrl);
      if (mounted) setState(() => _deposit = deposit);
    } catch (_) {}
  }

  @override
  void dispose() {
    _marketIdController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('发起争议', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        if (_deposit > BigInt.zero)
          Padding(padding: EdgeInsets.only(top: 4), child: Text(
            '所需保证金：${(_deposit.toDouble() / 1e18).toStringAsFixed(2)} CORN',
            style: TextStyle(fontSize: 12, color: AppTheme.muted))),
        SizedBox(height: 12),
        TextField(controller: _marketIdController, keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '市场 ID')),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(8)),
          child: DropdownButton<int>(
            value: _disputeType, isExpanded: true, underline: SizedBox.shrink(),
            items: [0, 1].map((i) => DropdownMenuItem(value: i, child: Text(_disputeTypes[i]))).toList(),
            onChanged: (v) { if (v != null) setState(() => _disputeType = v); },
          ),
        ),
        SizedBox(height: 8),
        TextField(controller: _reasonController, decoration: InputDecoration(hintText: '该结果为何有误')),
        SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () {
            final marketId = int.tryParse(_marketIdController.text);
            if (marketId == null || _reasonController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('请填写完整信息')));
              return;
            }
            final data = ContractService.raiseDisputeData(marketId, _disputeType, _reasonController.text);
            _showRawTx('发起争议', addr.humanHouseAddress, data);
          },
          child: Text('发起争议'),
        )),
      ],
    )));
  }

  void _showRawTx(String title, String to, String data) {
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

class _DisputeRow extends StatelessWidget {
  final DisputeData dispute;
  final VoidCallback onSelect;
  const _DisputeRow({required this.dispute, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final d = dispute;
    final total = d.votesFor + d.votesAgainst;
    final yesPct = total > BigInt.zero ? (d.votesFor.toDouble() / total.toDouble() * 100) : 50.0;

    return Card(child: InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(12),
      child: Padding(padding: EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('#${d.id}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _stateColors[d.state].withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_disputeStates[d.state], style: TextStyle(fontSize: 10, color: _stateColors[d.state], fontWeight: FontWeight.w500)),
            ),
            Spacer(),
            Text('${(d.deposit.toDouble() / 1e18).toStringAsFixed(2)} CORN', style: TextStyle(fontSize: 11, color: AppTheme.muted)),
          ]),
          SizedBox(height: 8),
          Row(children: [
            Text('市场 #${d.marketId}', style: TextStyle(fontSize: 12, color: AppTheme.primary)),
            SizedBox(width: 12),
            Text(_disputeTypes[d.disputeType], style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          ]),
          if (total > BigInt.zero) ...[
            SizedBox(height: 8),
            Row(children: [
              Text('${d.votesFor} 赞成', style: TextStyle(fontSize: 11, color: AppTheme.yes, fontWeight: FontWeight.w600)),
              SizedBox(width: 8),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: SizedBox(
                height: 6,
                child: Row(children: [
                  Expanded(flex: (yesPct * 10).toInt().clamp(1, 1000), child: Container(color: AppTheme.yes)),
                  Expanded(flex: ((100 - yesPct) * 10).toInt().clamp(1, 1000), child: Container(color: AppTheme.no)),
                ]),
              ))),
              SizedBox(width: 8),
              Text('${d.votesAgainst} 反对', style: TextStyle(fontSize: 11, color: AppTheme.no, fontWeight: FontWeight.w600)),
            ]),
          ],
        ],
      )),
    ));
  }
}

class _DisputeDetailPage extends ConsumerStatefulWidget {
  final int disputeId;
  final VoidCallback onBack;
  const _DisputeDetailPage({required this.disputeId, required this.onBack});

  @override
  ConsumerState<_DisputeDetailPage> createState() => _DisputeDetailPageState();
}

class _DisputeDetailPageState extends ConsumerState<_DisputeDetailPage> {
  Map<String, dynamic>? _dispute;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rpcUrl = ref.read(rpcUrlProvider);
    try {
      final data = await ContractService.getDispute(rpcUrl, widget.disputeId);
      if (mounted) setState(() { _dispute = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: Icon(Icons.arrow_back), onPressed: widget.onBack),
        title: Text('争议 #${widget.disputeId}', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(preferredSize: Size.fromHeight(0.5), child: Container(height: 0.5, color: AppTheme.border)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
          : _dispute == null
              ? Center(child: Text('加载失败', style: TextStyle(color: AppTheme.no)))
              : _buildDetail(),
    );
  }

  Widget _buildDetail() {
    final d = _dispute!;
    final state = d['state'] as int;
    final deadline = d['deadline'] as int;
    final votesFor = (d['votesFor'] as BigInt).toDouble();
    final votesAgainst = (d['votesAgainst'] as BigInt).toDouble();
    final total = votesFor + votesAgainst;
    final yesPct = total > 0 ? (votesFor / total * 100) : 50.0;
    final isActive = state == 0;
    final isExpired = DateTime.now().millisecondsSinceEpoch ~/ 1000 > deadline;

    return ListView(padding: EdgeInsets.all(16), children: [
      Card(child: Padding(padding: EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('争议 #${widget.disputeId}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _stateColors[state].withAlpha(25), borderRadius: BorderRadius.circular(12)),
              child: Text(_disputeStates[state], style: TextStyle(fontSize: 12, color: _stateColors[state], fontWeight: FontWeight.w500)),
            ),
          ]),
          SizedBox(height: 16),
          _infoRow('市场 ID', '#${d['marketId']}'),
          _infoRow('类型', _disputeTypes[d['disputeType'] as int]),
          _infoRow('发起人', '${(d['initiator'] as String).substring(0, 6)}...${(d['initiator'] as String).substring(38)}'),
          _infoRow('保证金', '${(d['deposit'] as BigInt).toDouble() / 1e18} CORN'),
          _infoRow('截止时间', DateTime.fromMillisecondsSinceEpoch(deadline * 1000).toString().substring(0, 16)),
          SizedBox(height: 16),

          // Vote bar
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('赞成 ${votesFor.toInt()}', style: TextStyle(fontSize: 13, color: AppTheme.yes, fontWeight: FontWeight.w600)),
            Text('${total.toInt()} 票', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
            Text('反对 ${votesAgainst.toInt()}', style: TextStyle(fontSize: 13, color: AppTheme.no, fontWeight: FontWeight.w600)),
          ]),
          SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedBox(
            height: 12,
            child: Row(children: [
              Expanded(flex: (yesPct * 10).toInt().clamp(1, 1000), child: Container(color: AppTheme.yes)),
              Expanded(flex: ((100 - yesPct) * 10).toInt().clamp(1, 1000), child: Container(color: AppTheme.no)),
            ]),
          )),
          SizedBox(height: 16),

          if (isActive && !isExpired) ...[
            Divider(color: AppTheme.border),
            SizedBox(height: 8),
            Text('World ID 验证（模拟）', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('当前使用模拟证明，真正的 World ID 集成即将上线。', style: TextStyle(fontSize: 11, color: AppTheme.muted)),
            SizedBox(height: 12),
            Row(children: [
              Expanded(child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.yes, padding: EdgeInsets.symmetric(vertical: 10)),
                onPressed: () => _showRawTx('投赞成票', addr.humanHouseAddress, 'vote赞成'),
                child: Text('投赞成票', style: TextStyle(color: Colors.white)),
              )),
              SizedBox(width: 8),
              Expanded(child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.no, padding: EdgeInsets.symmetric(vertical: 10)),
                onPressed: () => _showRawTx('投反对票', addr.humanHouseAddress, 'vote反对'),
                child: Text('投反对票', style: TextStyle(color: Colors.white)),
              )),
            ]),
          ],

          if (isActive && isExpired) ...[
            Divider(color: AppTheme.border),
            SizedBox(height: 8),
            SizedBox(width: double.infinity, child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFF59E0B), padding: EdgeInsets.symmetric(vertical: 12)),
              onPressed: () => _showRawTx('执行争议裁决', addr.humanHouseAddress, 'executeDispute'),
              child: Text('执行争议裁决', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )),
          ],
        ],
      ))),
    ]);
  }

  Widget _infoRow(String label, String value) {
    return Padding(padding: EdgeInsets.only(bottom: 8), child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: AppTheme.muted)),
        Flexible(child: Text(value, style: TextStyle(fontSize: 13), textAlign: TextAlign.end)),
      ],
    ));
  }

  void _showRawTx(String title, String to, String data) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('请使用钱包签名: $title')));
  }
}
