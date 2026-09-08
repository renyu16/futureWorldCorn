import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reown_appkit/reown_appkit.dart';
import '../services/walletconnect_service.dart';
import '../services/wc_config.dart';
import 'wallet_provider.dart';

/// WalletConnect 会话状态（供 UI 重建）。
class WcSessionState {
  final bool connected;
  final String? address;
  const WcSessionState({this.connected = false, this.address});

  WcSessionState copyWith({bool? connected, String? address}) => WcSessionState(
        connected: connected ?? this.connected,
        address: address ?? this.address,
      );
}

class WalletConnectNotifier extends StateNotifier<WcSessionState> {
  WalletConnectNotifier(this._ref) : super(const WcSessionState()) {
    _init();
  }

  final Ref _ref;
  late final void Function(dynamic) _onConnect = (_) => _sync();
  late final void Function(dynamic) _onUpdate = (_) => _sync();
  late final void Function(dynamic) _onDisconnect = (_) => _sync();

  Future<void> _init() async {
    final modal = WalletConnectService.appKit;
    if (modal == null) return;
    modal.onModalConnect.subscribe(_onConnect);
    modal.onModalUpdate.subscribe(_onUpdate);
    modal.onModalDisconnect.subscribe(_onDisconnect);
    _sync();
  }

  void _sync() {
    final modal = WalletConnectService.appKit;
    if (modal == null) return;
    final connected = modal.isConnected;
    final address = WalletConnectService.connectedAddress;
    if (connected && address != null) {
      _ref.read(walletProvider.notifier).setAddress(address);
    } else if (!connected) {
      _ref.read(walletProvider.notifier).disconnect();
    }
    state = WcSessionState(connected: connected, address: address);
  }

  /// 供外部（如设置页）在连接/断开操作后手动刷新。
  void refresh() => _sync();

  @override
  void dispose() {
    final modal = WalletConnectService.appKit;
    if (modal != null) {
      modal.onModalConnect.unsubscribe(_onConnect);
      modal.onModalUpdate.unsubscribe(_onUpdate);
      modal.onModalDisconnect.unsubscribe(_onDisconnect);
    }
    super.dispose();
  }
}

/// AppKit 单例实例（由 app 启动时 init）。
final appKitModalProvider = Provider<ReownAppKitModal?>((ref) {
  return WalletConnectService.appKit;
});

final wcSessionProvider =
    StateNotifierProvider<WalletConnectNotifier, WcSessionState>((ref) {
  return WalletConnectNotifier(ref);
});

const wcChainName = 'World Chain Sepolia (4801)';
const wcProjectId = WcConfig.projectId;
