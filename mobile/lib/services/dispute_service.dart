import 'contract_service.dart';

class DisputeData {
  final int id;
  final int marketId;
  final int disputeType;
  final int state;
  final BigInt deposit;
  final int deadline;
  final BigInt votesFor;
  final BigInt votesAgainst;

  const DisputeData({
    required this.id,
    required this.marketId,
    required this.disputeType,
    required this.state,
    required this.deposit,
    required this.deadline,
    required this.votesFor,
    required this.votesAgainst,
  });

  double get yesPct {
    final total = votesFor + votesAgainst;
    if (total == BigInt.zero) return 50;
    return (votesFor.toDouble() / total.toDouble()) * 100;
  }

  String get stateLabel {
    if (state == 0) return '进行中';
    if (state == 1) return '已通过';
    if (state == 2) return '已驳回';
    return '未知';
  }

  String get typeLabel => disputeType == 0 ? '预言机结果' : '市场内容';
}

class DisputeService {
  static Future<List<DisputeData>> fetchForMarket(String rpcUrl, int marketId) async {
    try {
      final count = await ContractService.disputeCount(rpcUrl);
      if (count == 0) return [];

      final disputes = <DisputeData>[];
      for (int i = 1; i <= count; i++) {
        final data = await ContractService.getDispute(rpcUrl, i);
        if (data != null && data['marketId'] == marketId) {
          disputes.add(DisputeData(
            id: i,
            marketId: marketId,
            disputeType: data['disputeType'] as int,
            state: data['state'] as int,
            deposit: data['deposit'] as BigInt,
            deadline: data['deadline'] as int,
            votesFor: data['votesFor'] as BigInt,
            votesAgainst: data['votesAgainst'] as BigInt,
          ));
        }
      }

      return disputes.reversed.toList();
    } catch (_) {
      return [];
    }
  }
}
