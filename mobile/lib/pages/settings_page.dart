import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/rpc_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/walletconnect_provider.dart';
import '../services/walletconnect_service.dart';
import '../contracts/addresses.dart' as addr;
import '../theme/app_theme.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late TextEditingController _controller;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    final rpcUrl = ref.read(rpcUrlProvider);
    _controller = TextEditingController(text: rpcUrl == addr.defaultRpcUrl ? '' : rpcUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isValidUrl(String url) {
    if (url.isEmpty) return true;
    try {
      final u = Uri.parse(url);
      return u.scheme == 'http' || u.scheme == 'https';
    } catch (_) {
      return false;
    }
  }

  Future<void> _testConnection() async {
    final url = _controller.text.trim();
    if (url.isEmpty) return;
    setState(() => _testing = true);
    final ok = await ref.read(rpcProvider.notifier).testConnection(url);
    setState(() => _testing = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '连接成功' : ref.read(rpcProvider).error ?? '连接失败'),
        backgroundColor: ok ? AppTheme.yes : AppTheme.no,
        duration: Duration(seconds: ok ? 2 : 4),
      ),
    );
  }

  Future<void> _save() async {
    final url = _controller.text.trim();
    if (!_isValidUrl(url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL 格式无效'), backgroundColor: AppTheme.no),
      );
      return;
    }
    final ok = await ref.read(rpcProvider.notifier).saveRpcUrl(url);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '设置已保存，返回首页生效' : '保存失败'),
        backgroundColor: ok ? AppTheme.yes : AppTheme.no,
      ),
    );
  }

  Future<void> _restoreDefault() async {
    await ref.read(rpcProvider.notifier).restoreDefault();
    _controller.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已恢复默认'), backgroundColor: AppTheme.primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rpcState = ref.watch(rpcProvider);
    final isValid = _isValidUrl(_controller.text);
    final currentRpc = rpcState.url;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('网络设置', style: TextStyle(fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('RPC URL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _controller,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'http://8.141.100.69:8085/rpc',
                      ),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    ),
                    if (!isValid) ...[
                      const SizedBox(height: 4),
                      const Text('URL 格式无效（需要 http:// 或 https:// 开头）',
                        style: TextStyle(color: AppTheme.no, fontSize: 12)),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isValid ? _save : null,
                            child: const Text('保存'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: (_testing || _controller.text.isEmpty) ? null : _testConnection,
                            child: _testing
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('测试连接'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _restoreDefault,
                      child: const Text('恢复默认'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, size: 16,
                          color: rpcState.url != addr.defaultRpcUrl ? AppTheme.yes : AppTheme.muted),
                        const SizedBox(width: 6),
                        const Text('当前生效：', style: TextStyle(fontSize: 13, color: AppTheme.muted)),
                        Expanded(
                          child: Text(currentRpc, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                            overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _WalletSection(),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('常见 RPC 节点', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    _rpcHint('默认', addr.defaultRpcUrl),
                    _rpcHint('局域网示例', 'http://192.168.1.100:8545'),
                    _rpcHint('本机测试', 'http://127.0.0.1:8545（需 adb reverse）'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rpcHint(String label, String url) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text('$label：', style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
          Expanded(
            child: Text(url, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _WalletSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_WalletSection> createState() => _WalletSectionState();
}

class _WalletSectionState extends ConsumerState<_WalletSection> {
  late TextEditingController _controller;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    final addr = ref.read(walletAddressProvider);
    _controller = TextEditingController(text: addr ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _connectWallet() async {
    if (!WalletConnectService.isInitialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WalletConnect 尚未就绪，请稍后重试')),
        );
      }
      return;
    }
    setState(() => _connecting = true);
    try {
      await WalletConnectService.connect();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('连接钱包失败')),
        );
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
      ref.read(wcSessionProvider.notifier).refresh();
    }
  }

  Future<void> _disconnectWallet() async {
    await WalletConnectService.disconnect();
    ref.read(wcSessionProvider.notifier).refresh();
    _controller.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已断开')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wc = ref.watch(wcSessionProvider);
    final wallet = ref.watch(walletProvider);
    final wcConnected = wc.connected;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.account_balance_wallet, size: 16,
                color: wcConnected ? AppTheme.yes : AppTheme.muted),
              const SizedBox(width: 6),
              Text(wcConnected ? '已连接钱包（WalletConnect）' : '连接钱包',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),

            // WalletConnect 连接按钮 / 状态
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: wcConnected ? null : _connectWallet,
                icon: _connecting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.wallet, size: 18),
                label: Text(wcConnected ? '已连接' : '连接钱包 (WalletConnect)'),
              ),
            ),
            if (wcConnected) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.check_circle, size: 14, color: AppTheme.yes),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(wc.address ?? wallet.address ?? '',
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.muted),
                    overflow: TextOverflow.ellipsis),
                ),
              ]),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _disconnectWallet,
                  child: const Text('断开连接'),
                ),
              ),
            ],

            if (!wcConnected) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text('或手动填写钱包地址（仅用于只读展示，无签名能力）',
                style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
              const SizedBox(height: 4),
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: '0x...  输入你的钱包地址',
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(walletProvider.notifier).setAddress(_controller.text);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('钱包地址已保存')),
                      );
                    },
                    child: const Text('保存'),
                  ),
                ),
                if (wallet.connected) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ref.read(walletProvider.notifier).disconnect();
                        _controller.clear();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已清除')),
                        );
                      },
                      child: const Text('清除'),
                    ),
                  ),
                ],
              ]),
              if (wallet.connected) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.check_circle, size: 14, color: AppTheme.yes),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(wallet.address!,
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.muted),
                      overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
