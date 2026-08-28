import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../contracts/addresses.dart' as addr;
import '../providers/rpc_provider.dart';

class MarketData {
  final int id;
  final String question;
  final double outcomeYes;
  final double outcomeNo;
  final int deadline;
  final int status;
  final bool result;

  const MarketData({
    required this.id,
    required this.question,
    required this.outcomeYes,
    required this.outcomeNo,
    required this.deadline,
    required this.status,
    required this.result,
  });

  double get totalPool => outcomeYes + outcomeNo;
  double get yesPct => totalPool > 0 ? (outcomeYes / totalPool) * 100 : 50;
  bool get isOpen => status == 0;
  bool get isResolved => status == 1;
  bool get isCancelled => status == 2;
  bool get isPendingResolve => status == 0 && deadline * 1000 < DateTime.now().millisecondsSinceEpoch;

  String get statusLabel {
    if (status == 1) return '已结算';
    if (status == 2) return '已取消';
    if (isPendingResolve) return '待结算';
    return '进行中';
  }
}

Future<Map<String, dynamic>> _rpcCall(String rpcUrl, String method, [List<dynamic> params = const []]) async {
  final uri = Uri.parse(rpcUrl);
  final body = jsonEncode({'jsonrpc': '2.0', 'method': method, 'params': params, 'id': 1});
  final res = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body)
      .timeout(const Duration(seconds: 15));
  return jsonDecode(res.body);
}

Future<List<MarketData>> fetchMarkets(String rpcUrl) async {
  final countResult = await _rpcCall(rpcUrl, 'eth_call', [
    {'to': addr.predictionMarketAddress, 'data': '0xec979082'},
    'latest'
  ]);
  final countHex = countResult['result'] as String? ?? '0x0';
  final count = int.parse(countHex.substring(2), radix: 16);
  if (count == 0) return [];

  final List<MarketData> markets = [];
  for (int i = 1; i <= count; i++) {
    try {
      final idHex = i.toRadixString(16).padLeft(64, '0');
      final data = '0xb1283e77$idHex';
      final result = await _rpcCall(rpcUrl, 'eth_call', [
        {'to': addr.predictionMarketAddress, 'data': data},
        'latest'
      ]);
      final raw = result['result'] as String? ?? '0x';
      if (raw.length < 514) continue;

      int wordOff(int n) => 2 + n * 64;

      final offset1 = int.parse(raw.substring(wordOff(0), wordOff(1)), radix: 16);
      final strLen = int.parse(raw.substring(wordOff(offset1 ~/ 32), wordOff(offset1 ~/ 32 + 1)), radix: 16);
      final question = utf8.decode(
        _hexToBytes(raw.substring(wordOff(offset1 ~/ 32 + 1), wordOff(offset1 ~/ 32 + 1) + strLen * 2)),
      );

      final outcomeYes = BigInt.parse(raw.substring(wordOff(1), wordOff(2)), radix: 16);
      final outcomeNo = BigInt.parse(raw.substring(wordOff(2), wordOff(3)), radix: 16);
      final deadline = int.parse(raw.substring(wordOff(3) + 54, wordOff(3) + 64), radix: 16);
      final statusVal = int.parse(raw.substring(wordOff(4) + 62, wordOff(4) + 64), radix: 16);
      final resultVal = raw.substring(wordOff(5) + 62, wordOff(5) + 64) == '01';

      markets.add(MarketData(
        id: i,
        question: question,
        outcomeYes: outcomeYes.toDouble() / 1e18,
        outcomeNo: outcomeNo.toDouble() / 1e18,
        deadline: deadline,
        status: statusVal,
        result: resultVal,
      ));
    } catch (e) {
      continue;
    }
  }
  return markets;
}

final marketsProvider = FutureProvider<List<MarketData>>((ref) async {
  final rpcUrl = ref.watch(rpcUrlProvider);
  return fetchMarkets(rpcUrl);
});

final marketDetailProvider = FutureProvider.family<MarketData?, int>((ref, marketId) async {
  final markets = await ref.watch(marketsProvider.future);
  try {
    return markets.firstWhere((m) => m.id == marketId);
  } catch (_) {
    return null;
  }
});

List<int> _hexToBytes(String hex) {
  final bytes = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return bytes;
}
