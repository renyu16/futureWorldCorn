import 'package:shared_preferences/shared_preferences.dart';
import '../contracts/addresses.dart' as addr;

class RpcService {
  static String _rpcUrl = addr.defaultRpcUrl;
  static bool _initialized = false;

  static String get rpcUrl => _rpcUrl;

  static Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _rpcUrl = prefs.getString(addr.storageKeyRpc) ?? addr.defaultRpcUrl;
    _initialized = true;
  }

  static Future<void> setRpcUrl(String url) async {
    _rpcUrl = url.isEmpty ? addr.defaultRpcUrl : url;
    final prefs = await SharedPreferences.getInstance();
    if (url.isEmpty) {
      await prefs.remove(addr.storageKeyRpc);
    } else {
      await prefs.setString(addr.storageKeyRpc, url);
    }
  }

  static bool get isCustom => _rpcUrl != addr.defaultRpcUrl;
}
