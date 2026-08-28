import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kWalletKey = 'wallet_address';

class WalletState {
  final String? address;
  final bool isLoading;
  const WalletState({this.address, this.isLoading = false});

  bool get connected => address != null && address!.length == 42;

  WalletState copyWith({String? address, bool? isLoading}) =>
      WalletState(address: address ?? this.address, isLoading: isLoading ?? this.isLoading);
}

class WalletNotifier extends StateNotifier<WalletState> {
  WalletNotifier() : super(const WalletState()) {
    _load();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    final prefs = await SharedPreferences.getInstance();
    final addr = prefs.getString(_kWalletKey);
    state = WalletState(address: addr, isLoading: false);
  }

  Future<void> setAddress(String addr) async {
    final clean = addr.trim();
    if (clean.length != 42 || !clean.startsWith('0x')) {
      state = const WalletState();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kWalletKey, clean);
    state = WalletState(address: clean);
  }

  Future<void> disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kWalletKey);
    state = const WalletState();
  }
}

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier();
});

final walletAddressProvider = Provider<String?>((ref) {
  return ref.watch(walletProvider).address;
});
