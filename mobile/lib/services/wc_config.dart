import 'package:reown_appkit/reown_appkit.dart';

class WcConfig {
  WcConfig._();

  static const String projectId = '38cfd0c495d4727d3d7e51ec3824a052';

  static const String redirectNative = 'futureworldcorn://';
  static const String redirectUniversal = 'https://futureworldcorn.app/';

  static PairingMetadata get pairingMetadata => PairingMetadata(
        name: '预测大师',
        description: 'World Chain Sepolia 预测市场 dApp',
        url: redirectUniversal,
        icons: const [],
        redirect: Redirect(
          native: redirectNative,
          universal: redirectUniversal,
          linkMode: false,
        ),
      );

  /// World Chain Sepolia: eip155:4801
  static ReownAppKitModalNetworkInfo get worldChainSepolia =>
      ReownAppKitModalNetworkInfo(
        name: 'World Chain Sepolia',
        chainId: '4801',
        currency: 'ETH',
        rpcUrl: 'https://worldchain-sepolia.g.alchemy.com/public',
        explorerUrl: 'https://sepolia.worldchainscan.com',
        isTestNetwork: true,
      );

  /// 内置钱包列表（离线可用）。
  /// 这样不依赖 api.web3modal.com 的钱包列表也能在弹窗里直接点 MetaMask，
  /// 走 `metamask://wc` 深度链接调起本机 MetaMask（无需二维码/第二台设备）。
  static final List<ReownAppKitModalWalletInfo> customWallets = [
    ReownAppKitModalWalletInfo(
      listing: AppKitModalWalletListing(
        id: 'c57ca95b47569778a828c19177414f77dbcdb65900e0e96399d89794f8f5c5b3',
        name: 'MetaMask',
        homepage: 'https://metamask.io/',
        imageId: '5195e9db-94d8-4579-6f11-ef553be95100',
        order: 10,
        supportsWc: true,
        androidAppId: 'io.metamask',
        mobileLink: 'metamask://wc',
        webappLink: 'https://metamask.app.link/wc',
      ),
    ),
  ];

  /// 精简支持链：只保留 eip155:4801（World Chain Sepolia）。
  /// 需在创建 ReownAppKitModal 之前调用。
  static void configureNetworks() {
    ReownAppKitModalNetworks.removeSupportedNetworks('eip155');
    for (final ns in const [
      'solana',
      'bip122',
      'near',
      'tron',
      'ton',
      'sui',
      'stacks',
    ]) {
      ReownAppKitModalNetworks.removeSupportedNetworks(ns);
    }
    ReownAppKitModalNetworks.removeTestNetworks();
    ReownAppKitModalNetworks.addSupportedNetworks('eip155', [
      worldChainSepolia,
    ]);
  }
}
