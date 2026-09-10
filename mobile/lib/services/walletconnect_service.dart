import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';
import '../contracts/addresses.dart' as addr;
import 'wc_config.dart';

/// 封装 Reown AppKit（WalletConnect v2 dApp 端）：
/// - 全局单例，持有 [ReownAppKitModal]
/// - 提供连接、断开、发交易能力
/// - [WalletConnect][] 会话地址需同步到 [walletProvider]（见 settings/create 页）
class WalletConnectService {
  WalletConnectService._();

  static ReownAppKitModal? _appKit;
  static ReownAppKitModal? get appKit => _appKit;
  static bool get isInitialized => _appKit != null;

  static const _namespace = 'eip155';

  /// 初始化 AppKit（重复调用安全）。需在 app 启动时以已挂载的 context 调用。
  static Future<void> initialize(BuildContext context) async {
    if (_appKit != null) return;
    WcConfig.configureNetworks();
    final modal = ReownAppKitModal(
      context: context,
      projectId: WcConfig.projectId,
      metadata: WcConfig.pairingMetadata,
      logLevel: LogLevel.debug,
      disconnectOnDispose: false,
      customWallets: WcConfig.customWallets,
    );
    modal.onModalError.subscribe((e) {
      debugPrint('[wcinst] onModalError: $e');
    });
    _appKit = modal;
    try {
      modal.appKit?.core.addLogListener((msg) {
        debugPrint('[wcore] $msg');
      });
      debugPrint('[wcinst] log listener attached');
    } catch (e, s) {
      debugPrint('[wcinst] addLogListener failed: $e $s');
    }
    final initDone = await modal.init().timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        debugPrint('[wcinst] modal.init() TIMED OUT after 20s');
        return;
      },
    );
    debugPrint('[wcinst] modal.init() returned');
    debugPrint('[wcinst] initialized; relayUrl=${modal.appKit?.core.relayUrl}');
  }

  static bool get isConnected => _appKit?.isConnected ?? false;

  /// 当前已连接的 eip155 地址
  static String? get connectedAddress {
    final s = _appKit?.session;
    if (s == null) return null;
    return s.getAddress(_namespace);
  }

  /// 当前连接的钱包地址（short form 显示的辅助；也可直接用 [connectedAddress]）
  static String? get currentTopic => _appKit?.session?.topic;

  /// 发起 eth_sendTransaction。
  /// [to] 目标合约地址，[data] 已编码的 calldata（0x 开头）。
  /// 返回交易哈希（由钱包端签名并广播，可能是 WC relay 返回的哈希）。
  static Future<String> sendEthTransaction({
    required String to,
    required String data,
  }) async {
    final modal = _effective();
    if (!modal.isConnected || modal.session == null) {
      throw Exception('钱包未连接，请先在设置中连接钱包');
    }
    final from = modal.session!.getAddress(_namespace);
    if (from == null) {
      throw Exception('会话中未找到 eip155 地址');
    }
    final chainId = 'eip155:${addr.chainId}';
    final tx = <String, dynamic>{
      'from': from,
      'to': to,
      'data': data,
    };
    final response = await modal.request(
      topic: modal.session!.topic,
      chainId: chainId,
      request: SessionRequestParams(
        method: 'eth_sendTransaction',
        params: [tx],
      ),
    );
    if (response == null) {
      throw Exception('钱包未返回交易哈希');
    }
    return response.toString();
  }

  static ReownAppKitModal _effective() {
    if (_appKit == null) {
      throw Exception('WalletConnect 未初始化');
    }
    return _appKit!;
  }

  /// 发起连接（打开 AppKit 内置选择钱包弹窗）
  static Future<void> connect() async {
    final modal = _effective();
    _watchWcUri(modal);
    await modal.openModalView();
  }

  /// 诊断辅助：轮询打印连接期间生成的 wcUri（release 也走 debugPrint 到 logcat）
  static void _watchWcUri(ReownAppKitModal modal) {
    debugPrint('[wcup] watch start');
    var last = '';
    var count = 0;
    Timer.periodic(const Duration(milliseconds: 800), (t) {
      final uri = modal.wcUri ?? '';
      if (uri != last) {
        count = 0;
        debugPrint('[wcup] uri = $uri');
        debugPrint('[wcup] key  = ${modal.session?.peer?.metadata?.name}');
        last = uri;
      } else if (uri.isNotEmpty) {
        count++;
      }
      if (modal.isConnected && modal.session != null) {
        debugPrint('[wcup] session established topic=${modal.session?.topic}');
        t.cancel();
      }
      if (uri.isNotEmpty && count > 120) {
        debugPrint('[wcup] stop (uri held, no session)');
        t.cancel();
      }
      if (modal.isOpen == false && uri.isEmpty) {
        debugPrint('[wcup] modal closed without uri');
        t.cancel();
      }
    });
  }

  static Future<void> disconnect() async {
    final modal = _effective();
    await modal.disconnect();
  }
}
