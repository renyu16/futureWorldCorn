import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../contracts/addresses.dart' as addr;

class ContractService {
  static Future<dynamic> _ethCall(String rpcUrl, String to, String data) async {
    final uri = Uri.parse(rpcUrl);
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'method': 'eth_call',
      'params': [{'to': to, 'data': data}, 'latest'],
      'id': 1,
    });
    final res = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 15));
    final json = jsonDecode(res.body);
    if (json['error'] != null) throw Exception(json['error']['message']);
    return json['result'];
  }

  static String _addrPad(String address) => address.toLowerCase().replaceFirst('0x', '').padLeft(64, '0');
  static String _uintPad(BigInt val) => val.toRadixString(16).padLeft(64, '0');
  static String _uintPadInt(int val) => val.toRadixString(16).padLeft(64, '0');

  static String _encodeBytes32(String value) {
    final bytes = utf8.encode(value);
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return hex.padRight(64, '0');
  }

  static Future<BigInt> _readUint(String rpcUrl, String to, String data) async {
    final result = await _ethCall(rpcUrl, to, data);
    if (result == null || result == '0x') return BigInt.zero;
    return BigInt.parse(result.substring(2), radix: 16);
  }

  static Future<bool> _readBool(String rpcUrl, String to, String data) async {
    final val = await _readUint(rpcUrl, to, data);
    return val != BigInt.zero;
  }

  // ── Token reads ──

  static Future<BigInt> tokenBalance(String rpcUrl, String userAddress) async {
    return _readUint(rpcUrl, addr.cornTokenAddress, '0x70a08231$_addrPad(userAddress)');
  }

  static Future<BigInt> tokenAllowance(String rpcUrl, String userAddress) async {
    final ownerPad = _addrPad(userAddress);
    final spenderPad = _addrPad(addr.predictionMarketAddress);
    return _readUint(rpcUrl, addr.cornTokenAddress, '0xdd62ed3f$ownerPad$spenderPad');
  }

  static Future<BigInt> tokenAllowanceTo(String rpcUrl, String userAddress, String spenderAddress) async {
    final ownerPad = _addrPad(userAddress);
    final spenderPad = _addrPad(spenderAddress);
    return _readUint(rpcUrl, addr.cornTokenAddress, '0xdd62ed3f$ownerPad$spenderPad');
  }

  // ── govCORN reads ──

  static Future<BigInt> govCornBalance(String rpcUrl, String userAddress) async {
    return _readUint(rpcUrl, addr.govCornTokenAddress, '0x70a08231${_addrPad(userAddress)}');
  }

  static Future<BigInt> govCornVotes(String rpcUrl, String userAddress) async {
    return _readUint(rpcUrl, addr.govCornTokenAddress, '0x9a5e179d${_addrPad(userAddress)}');
  }

  static Future<String> govCornDelegates(String rpcUrl, String userAddress) async {
    final result = await _ethCall(rpcUrl, addr.govCornTokenAddress, '0x765722e1${_addrPad(userAddress)}');
    if (result == null || result == '0x') return '';
    return '0x${result.substring(26)}';
  }

  // ── Market reads ──

  static Future<String> marketOwner(String rpcUrl) async {
    final result = await _ethCall(rpcUrl, addr.predictionMarketAddress, '0x8da5cb5b');
    if (result == null || result == '0x') return '';
    return '0x${result.substring(26)}';
  }

  static Future<bool> isResolver(String rpcUrl, String userAddress) async {
    return _readBool(rpcUrl, addr.predictionMarketAddress, '0x${"d784d426"}${_addrPad(userAddress)}');
  }

  static Future<int> defaultFeeBps(String rpcUrl) async {
    final val = await _readUint(rpcUrl, addr.predictionMarketAddress, '0x2e56409e');
    return val.toInt();
  }

  static Future<BigInt> userSharesYes(String rpcUrl, int marketId, String userAddress) async {
    return _readUint(rpcUrl, addr.predictionMarketAddress, '0x01ffc9a7${_uintPadInt(marketId)}${_addrPad(userAddress)}');
  }

  static Future<BigInt> userSharesNo(String rpcUrl, int marketId, String userAddress) async {
    return _readUint(rpcUrl, addr.predictionMarketAddress, '0x5b94452e${_uintPadInt(marketId)}${_addrPad(userAddress)}');
  }

  static Future<bool> claimed(String rpcUrl, int marketId, String userAddress) async {
    return _readBool(rpcUrl, addr.predictionMarketAddress, '0x0b795f2a${_uintPadInt(marketId)}${_addrPad(userAddress)}');
  }

  // ── TokenHouse reads ──

  static Future<int> proposalState(String rpcUrl, int proposalId) async {
    final val = await _readUint(rpcUrl, addr.tokenHouseAddress, '0x317240ea${_uintPadInt(proposalId)}');
    return val.toInt();
  }

  static Future<List<BigInt>> proposalVotes(String rpcUrl, int proposalId) async {
    final result = await _ethCall(rpcUrl, addr.tokenHouseAddress, '0x57040343${_uintPadInt(proposalId)}');
    if (result == null || result.length < 194) return [BigInt.zero, BigInt.zero, BigInt.zero];
    int w(int n) => 2 + n * 64;
    return [
      BigInt.parse(result.substring(w(0), w(1)), radix: 16),
      BigInt.parse(result.substring(w(1), w(2)), radix: 16),
      BigInt.parse(result.substring(w(2), w(3)), radix: 16),
    ];
  }

  static Future<String> proposalProposer(String rpcUrl, int proposalId) async {
    final result = await _ethCall(rpcUrl, addr.tokenHouseAddress, '0x4613dc10${_uintPadInt(proposalId)}');
    if (result == null || result == '0x') return '';
    return '0x${result.substring(26)}';
  }

  static Future<int> proposalDeadlineBlock(String rpcUrl, int proposalId) async {
    final val = await _readUint(rpcUrl, addr.tokenHouseAddress, '0x0b8a0448${_uintPadInt(proposalId)}');
    return val.toInt();
  }

  static Future<int> proposalSnapshotBlock(String rpcUrl, int proposalId) async {
    final val = await _readUint(rpcUrl, addr.tokenHouseAddress, '0x3a087523${_uintPadInt(proposalId)}');
    return val.toInt();
  }

  static Future<BigInt> proposalThreshold(String rpcUrl) async {
    return _readUint(rpcUrl, addr.tokenHouseAddress, '0x3388838e');
  }

  // ── Dispute reads ──

  static Future<int> disputeCount(String rpcUrl) async {
    final val = await _readUint(rpcUrl, addr.humanHouseAddress, '0xeb8d2a04');
    return val.toInt();
  }

  static Future<BigInt> disputeDeposit(String rpcUrl) async {
    return _readUint(rpcUrl, addr.humanHouseAddress, '0x43058948');
  }

  static Future<BigInt> disputeVotingPeriod(String rpcUrl) async {
    return _readUint(rpcUrl, addr.humanHouseAddress, '0xd6a3844a');
  }

  static Future<Map<String, dynamic>?> getDispute(String rpcUrl, int disputeId) async {
    try {
      final result = await _ethCall(rpcUrl, addr.humanHouseAddress, '0x83d59542${_uintPadInt(disputeId)}');
      if (result == null || result == '0x' || result.length < 514) return null;
      int w(int n) => 2 + n * 64;
      return {
        'marketId': int.parse(result.substring(w(0) + 48, w(1)), radix: 16),
        'disputeType': int.parse(result.substring(w(1) + 62, w(2)), radix: 16),
        'state': int.parse(result.substring(w(2) + 62, w(3)), radix: 16),
        'initiator': '0x${result.substring(w(3) + 24, w(4))}',
        'deposit': BigInt.parse(result.substring(w(4), w(5)), radix: 16),
        'deadline': int.parse(result.substring(w(5) + 48, w(6)), radix: 16),
        'votesFor': BigInt.parse(result.substring(w(7), w(8)), radix: 16),
        'votesAgainst': BigInt.parse(result.substring(w(8), w(9)), radix: 16),
      };
    } catch (_) {
      return null;
    }
  }

  // ── Event logs ──

  static Future<List<Map<String, dynamic>>> getBetPlacedLogs(String rpcUrl, int marketId) async {
    final idPad = _uintPadInt(marketId);
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'method': 'eth_getLogs',
      'params': [{
        'address': addr.predictionMarketAddress,
        'topics': ['0xe0ced7bdb8dba52592794c53dd6db804f2e41b8e08a7e80935d3c644f9e7556', idPad],
      }],
      'id': 1,
    });
    final uri = Uri.parse(rpcUrl);
    final res = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 15));
    final json = jsonDecode(res.body);
    if (json['error'] != null) return [];
    final logs = (json['result'] as List?) ?? [];
    return logs.map<Map<String, dynamic>>((log) {
      final data = (log['data'] as String).substring(2);
      final outcome = int.parse(data.substring(0, 64), radix: 16);
      final amount = BigInt.parse(data.substring(64, 128), radix: 16);
      final txHash = log['transactionHash'] as String;
      return {
        'outcome': outcome,
        'amount': amount,
        'blockNumber': log['blockNumber'],
        'txHash': txHash,
      };
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> getProposalCreatedLogs(String rpcUrl) async {
    final topic = '0x7d84a6263ae0d98d3329bd7b46bb4e8d6f98cd35a7adb45c274c8b7fd5ebd5e0';
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'method': 'eth_getLogs',
      'params': [{'address': addr.tokenHouseAddress, 'topics': [topic]}],
      'id': 1,
    });
    final uri = Uri.parse(rpcUrl);
    final res = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 15));
    final json = jsonDecode(res.body);
    if (json['error'] != null) return [];
    final logs = (json['result'] as List?) ?? [];
    return logs.map<Map<String, dynamic>>((log) {
      final topics = (log['topics'] as List).cast<String>();
      final proposalId = int.parse(topics[1].substring(26), radix: 16);
      final data = (log['data'] as String).substring(2);
      // description is the last dynamic field
      final lastDynOffset = int.parse(data.substring(data.length - 128, data.length - 64), radix: 16);
      final descLen = int.parse(data.substring(data.length - 64), radix: 16);
      final descStart = lastDynOffset * 2;
      final descBytes = _hexToBytes(data.substring(descStart, descStart + descLen * 2));
      final description = utf8.decode(descBytes, allowMalformed: true);
      return {'proposalId': proposalId, 'description': description};
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> getDisputeCreatedLogs(String rpcUrl) async {
    final topic = '0xd040e3d8a268cd295b5f89ec2e2534dd45f107f73bbefda49c554c14ab5b44cb';
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'method': 'eth_getLogs',
      'params': [{'address': addr.humanHouseAddress, 'topics': [topic]}],
      'id': 1,
    });
    final uri = Uri.parse(rpcUrl);
    final res = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 15));
    final json = jsonDecode(res.body);
    if (json['error'] != null) return [];
    final logs = (json['result'] as List?) ?? [];
    return logs.map<Map<String, dynamic>>((log) {
      final topics = (log['topics'] as List).cast<String>();
      return {
        'disputeId': int.parse(topics[1].substring(26), radix: 16),
        'marketId': int.parse(topics[2].substring(26), radix: 16),
        'blockNumber': log['blockNumber'],
      };
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> getVoteCastLogs(String rpcUrl, {int? disputeId}) async {
    final topic = '0xa569f04ac50c7dc602af46da32d6b4bb55adafc0bc482968f959264ea5edde96';
    final topicsList = <String>[topic];
    if (disputeId != null) topicsList.add(_uintPadInt(disputeId));
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'method': 'eth_getLogs',
      'params': [{'address': addr.humanHouseAddress, 'topics': topicsList}],
      'id': 1,
    });
    final uri = Uri.parse(rpcUrl);
    final res = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 15));
    final json = jsonDecode(res.body);
    if (json['error'] != null) return [];
    final logs = (json['result'] as List?) ?? [];
    return logs.map<Map<String, dynamic>>((log) {
      final data = (log['data'] as String).substring(2);
      return {
        'disputeId': int.parse(log['topics'][1].substring(26), radix: 16),
        'support': data.substring(2, 66).endsWith('01'),
        'blockNumber': log['blockNumber'],
      };
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> getDisputeExecutedLogs(String rpcUrl) async {
    final topic = '0x606f6ccbd7f9c4089b2e0e3f07b80bc5e91da4da19f38e1747bde0755ae2ad28';
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'method': 'eth_getLogs',
      'params': [{'address': addr.humanHouseAddress, 'topics': [topic]}],
      'id': 1,
    });
    final uri = Uri.parse(rpcUrl);
    final res = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 15));
    final json = jsonDecode(res.body);
    if (json['error'] != null) return [];
    final logs = (json['result'] as List?) ?? [];
    return logs.map<Map<String, dynamic>>((log) {
      final data = (log['data'] as String).substring(2);
      return {
        'disputeId': int.parse(log['topics'][1].substring(26), radix: 16),
        'outcome': int.parse(data.substring(0, 64), radix: 16),
        'blockNumber': log['blockNumber'],
      };
    }).toList();
  }

  static List<int> _hexToBytes(String hex) {
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  static Future<int> getBlockTimestamp(String rpcUrl, String blockNumber) async {
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'method': 'eth_getBlockByNumber',
      'params': [blockNumber, false],
      'id': 1,
    });
    final uri = Uri.parse(rpcUrl);
    final res = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 15));
    final json = jsonDecode(res.body);
    if (json['result'] != null) {
      return int.parse((json['result']['timestamp'] as String).substring(2), radix: 16);
    }
    return 0;
  }

  // ── Write transaction data builders ──

  static String approveData(String spenderAddress, BigInt amount) {
    return '0x095ea7b3${_addrPad(spenderAddress)}${_uintPad(amount)}';
  }

  static String betData(int marketId, int outcome, BigInt amount) {
    return '0xd53d1794${_uintPadInt(marketId)}${outcome.toRadixString(16).padLeft(64, '0')}${_uintPad(amount)}';
  }

  static String claimRewardData(int marketId) {
    return '0x367bbd2c${_uintPadInt(marketId)}';
  }

  static String resolveMarketData(int marketId, bool result) {
    return '0x8b4e8f54${_uintPadInt(marketId)}${result ? '0000000000000000000000000000000000000000000000000000000000000001' : '0000000000000000000000000000000000000000000000000000000000000000'}';
  }

  static String raiseDisputeData(int marketId, int disputeType, String reason) {
    final typeHex = disputeType.toRadixString(16).padLeft(64, '0');
    final reasonOffset = (3 * 32).toRadixString(16).padLeft(64, '0');
    final reasonLen = reason.length.toRadixString(16).padLeft(64, '0');
    final reasonPadded = _encodeBytes32(reason);
    return '0xf3c99269$typeHex$reasonOffset$reasonLen$reasonPadded';
  }

  static String depositForData(String userAddress, BigInt amount) {
    return '0xb28bcc8e${_addrPad(userAddress)}${_uintPad(amount)}';
  }

  static String withdrawToData(String userAddress, BigInt amount) {
    return '0x693ec85e${_addrPad(userAddress)}${_uintPad(amount)}';
  }

  static String delegateData(String delegateeAddress) {
    return '0x5c19a95c${_addrPad(delegateeAddress)}';
  }

  static String castVoteData(int proposalId, int support) {
    return '0xc0246668${_uintPadInt(proposalId)}${support.toRadixString(16).padLeft(64, '0')}';
  }

  static Future<bool> isMarketCreator(String rpcUrl, String userAddress) {
    return _readBool(rpcUrl, addr.predictionMarketAddress, '0x1d6c8bc8${_addrPad(userAddress)}');
  }

  static String createMarketData(String question, int deadline, int feeBps) {
    final qBytes = utf8.encode(question);
    final qLen = qBytes.length;
    final qHex = qBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final qPaddedLen = ((qLen + 31) ~/ 32) * 32;
    final qPadded = qHex.padRight(qPaddedLen * 2, '0');
    return '0xd4c034b7'
        '${(96).toRadixString(16).padLeft(64, '0')}'
        '${deadline.toRadixString(16).padLeft(64, '0')}'
        '${feeBps.toRadixString(16).padLeft(64, '0')}'
        '${qLen.toRadixString(16).padLeft(64, '0')}'
        '$qPadded';
  }
}
