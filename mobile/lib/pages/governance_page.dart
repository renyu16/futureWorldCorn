import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:future_world_corn_mobile/providers/wallet_provider.dart';
import 'package:future_world_corn_mobile/providers/rpc_provider.dart';
import 'package:future_world_corn_mobile/services/contract_service.dart';
import 'package:future_world_corn_mobile/contracts/addresses.dart' as addr;
import 'package:future_world_corn_mobile/theme/app_theme.dart';

const _stateLabels = ['待定', '进行中', '已取消', '未通过', '已通过', '已排队', '已过期', '已执行'];
const _stateColors = [null, AppTheme.primary, AppTheme.muted, AppTheme.no, AppTheme.yes, AppTheme.yes, AppTheme.muted, AppTheme.yes];

class GovernancePage extends ConsumerStatefulWidget {
  const GovernancePage({super.key});
  @override
  ConsumerState<GovernancePage> createState() => _GovernancePageState();
}

class _GovernancePageState extends ConsumerState<GovernancePage> {
  List<Map<String, dynamic>> _proposals = [];
  bool _loading = false;
  String? _error;
  int? _selectedId;
  bool _showForm = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rpcUrl = ref.read(rpcUrlProvider);
    setState(() { _loading = true; _error = null; });
    try {
      final logs = await ContractService.getProposalCreatedLogs(rpcUrl);
      if (mounted) setState(() { _proposals = logs.reversed.toList(); _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '提案加载失败'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);

    if (_selectedId != null) {
      return _ProposalDetail(proposalId: _selectedId!, onBack: () => setState(() => _selectedId = null));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('治理', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (wallet.connected)
            IconButton(
              icon: Icon(_showForm ? Icons.close : Icons.add, color: AppTheme.primary),
              onPressed: () => setState(() => _showForm = !_showForm),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppTheme.border),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: EdgeInsets.all(16), children: [
          if (_showForm) _CreateProposalCard(
            onCreated: () { setState(() => _showForm = false); _load(); },
          ),
          if (_loading)
            Center(child: Padding(padding: EdgeInsets.all(32), child: Text('加载提案中...', style: TextStyle(color: AppTheme.muted))))
          else if (_error != null)
            Center(child: Text(_error!, style: TextStyle(color: AppTheme.no)))
          else if (_proposals.isEmpty)
            Center(child: Padding(padding: EdgeInsets.all(32), child: Text('暂无提案', style: TextStyle(color: AppTheme.muted))))
          else
            ..._proposals.map((p) => Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _ProposalRow(
                proposal: p,
                onSelect: () => setState(() => _selectedId = p['proposalId'] as int),
              ),
            )),
        ]),
      ),
    );
  }
}

class _ProposalRow extends StatelessWidget {
  final Map<String, dynamic> proposal;
  final VoidCallback onSelect;
  const _ProposalRow({required this.proposal, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final id = proposal['proposalId'] as int;
    final desc = proposal['description'] as String;
    final truncated = desc.length > 80 ? '${desc.substring(0, 80)}...' : desc;

    return Card(child: InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(12),
      child: Padding(padding: EdgeInsets.all(16), child: Row(
        children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('#$id', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                SizedBox(width: 8),
                _ProposalStateBadge(proposalId: id),
              ]),
              SizedBox(height: 4),
              Text(truncated, style: TextStyle(fontSize: 12, color: AppTheme.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          )),
          Icon(Icons.chevron_right, color: AppTheme.muted),
        ],
      )),
    ));
  }
}

class _ProposalStateBadge extends ConsumerWidget {
  final int proposalId;
  const _ProposalStateBadge({required this.proposalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rpcUrl = ref.read(rpcUrlProvider);
    return FutureBuilder<int>(
      future: ContractService.proposalState(rpcUrl, proposalId),
      builder: (ctx, snap) {
        final state = snap.data ?? 0;
        final label = state < _stateLabels.length ? _stateLabels[state] : '未知';
        final color = state < _stateColors.length ? (_stateColors[state] ?? AppTheme.muted) : AppTheme.muted;
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(8)),
          child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
        );
      },
    );
  }
}

class _ProposalDetail extends ConsumerStatefulWidget {
  final int proposalId;
  final VoidCallback onBack;
  const _ProposalDetail({required this.proposalId, required this.onBack});

  @override
  ConsumerState<_ProposalDetail> createState() => _ProposalDetailState();
}

class _ProposalDetailState extends ConsumerState<_ProposalDetail> {
  int _state = 0;
  List<BigInt> _votes = [BigInt.zero, BigInt.zero, BigInt.zero];
  String _proposer = '';
  int _deadlineBlock = 0;
  int _snapshotBlock = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rpcUrl = ref.read(rpcUrlProvider);
    try {
      final results = await Future.wait([
        ContractService.proposalState(rpcUrl, widget.proposalId),
        ContractService.proposalVotes(rpcUrl, widget.proposalId),
        ContractService.proposalProposer(rpcUrl, widget.proposalId),
        ContractService.proposalDeadlineBlock(rpcUrl, widget.proposalId),
        ContractService.proposalSnapshotBlock(rpcUrl, widget.proposalId),
      ]);
      if (mounted) setState(() {
        _state = results[0] as int;
        _votes = results[1] as List<BigInt>;
        _proposer = results[2] as String;
        _deadlineBlock = results[3] as int;
        _snapshotBlock = results[4] as int;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final label = _state < _stateLabels.length ? _stateLabels[_state] : '未知';
    final color = _state < _stateColors.length ? (_stateColors[_state] ?? AppTheme.muted) : AppTheme.muted;
    final isActive = _state == 1;
    final against = _votes[0].toDouble() / 1e18;
    final forVotes = _votes[1].toDouble() / 1e18;
    final abstain = _votes[2].toDouble() / 1e18;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: Icon(Icons.arrow_back), onPressed: widget.onBack),
        title: Text('提案 #${widget.proposalId}', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(preferredSize: Size.fromHeight(0.5), child: Container(height: 0.5, color: AppTheme.border)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
          : ListView(padding: EdgeInsets.all(16), children: [
              Card(child: Padding(padding: EdgeInsets.all(16), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('提案 #${widget.proposalId}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(12)),
                      child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
                    ),
                  ]),
                  SizedBox(height: 16),
                  _infoRow('提案人', _proposer.isNotEmpty ? '${_proposer.substring(0, 6)}...${_proposer.substring(38)}' : '-'),
                  _infoRow('快照区块', '$_snapshotBlock'),
                  _infoRow('截止区块', '$_deadlineBlock'),
                  SizedBox(height: 16),
                  Row(children: [
                    _voteItem('赞成', forVotes, AppTheme.yes),
                    _voteItem('反对', against, AppTheme.no),
                    _voteItem('弃权', abstain, AppTheme.muted),
                  ]),
                  if (isActive && wallet.connected) ...[
                    SizedBox(height: 16),
                    Divider(color: AppTheme.border),
                    SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _voteButton('赞成', AppTheme.yes, 1)),
                      SizedBox(width: 8),
                      Expanded(child: _voteButton('反对', AppTheme.no, 0)),
                      SizedBox(width: 8),
                      Expanded(child: _voteButton('弃权', AppTheme.muted, 2)),
                    ]),
                  ],
                ],
              ))),
            ]),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(padding: EdgeInsets.only(bottom: 8), child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: AppTheme.muted)),
        Text(value, style: TextStyle(fontSize: 13, fontFamily: 'monospace')),
      ],
    ));
  }

  Widget _voteItem(String label, double amount, Color color) {
    return Expanded(child: Column(children: [
      Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      SizedBox(height: 4),
      Text('${amount.toStringAsFixed(4)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      Text('govCORN', style: TextStyle(fontSize: 10, color: AppTheme.muted)),
    ]));
  }

  Widget _voteButton(String label, Color color, int support) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: color, padding: EdgeInsets.symmetric(vertical: 10)),
      onPressed: () {
        final data = ContractService.castVoteData(widget.proposalId, support);
        _showRawTx('投票: $label', addr.tokenHouseAddress, data);
      },
      child: Text(label, style: TextStyle(color: Colors.white, fontSize: 13)),
    );
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

class _CreateProposalCard extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateProposalCard({required this.onCreated});

  @override
  ConsumerState<_CreateProposalCard> createState() => _CreateProposalCardState();
}

class _CreateProposalCardState extends ConsumerState<_CreateProposalCard> {
  final _targetController = TextEditingController();
  final _valueController = TextEditingController(text: '0');
  final _funcSigController = TextEditingController();
  final _argsController = TextEditingController(text: '[]');
  final _descController = TextEditingController();

  @override
  void dispose() {
    _targetController.dispose();
    _valueController.dispose();
    _funcSigController.dispose();
    _argsController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('创建提案', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        SizedBox(height: 4),
        Text('提交链上治理提案。需要 govCORN 投票权达到门槛以上。', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
        SizedBox(height: 12),
        TextField(controller: _targetController, decoration: InputDecoration(hintText: '目标地址 0x...')),
        SizedBox(height: 8),
        TextField(controller: _valueController, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: 'ETH 数值 (wei)')),
        SizedBox(height: 8),
        TextField(controller: _funcSigController, decoration: InputDecoration(hintText: '函数签名（可选）例: transfer(address,uint256)')),
        if (_funcSigController.text.isNotEmpty) ...[
          SizedBox(height: 8),
          TextField(controller: _argsController, decoration: InputDecoration(hintText: '参数 JSON 数组')),
        ],
        SizedBox(height: 8),
        TextField(controller: _descController, maxLines: 3, decoration: InputDecoration(hintText: '描述')),
        SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('请使用钱包签名创建提案')));
          },
          child: Text('提交提案'),
        )),
      ],
    )));
  }
}
