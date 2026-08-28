import 'contract_service.dart';

class PricePoint {
  final int timestamp;
  final double yesPrice;
  final double noPrice;
  const PricePoint({required this.timestamp, required this.yesPrice, required this.noPrice});
}

class PriceHistoryService {
  static Future<List<PricePoint>> fetch(String rpcUrl, int marketId, double currentYesPool, double currentNoPool) async {
    try {
      final logs = await ContractService.getBetPlacedLogs(rpcUrl, marketId);
      if (logs.isEmpty) return [];

      double cumYes = currentYesPool;
      double cumNo = currentNoPool;

      for (final log in logs) {
        final amount = (log['amount'] as BigInt).toDouble() / 1e18;
        if (log['outcome'] == 0) {
          cumYes -= amount;
        } else {
          cumNo -= amount;
        }
      }

      if (cumYes < 0) cumYes = 0;
      if (cumNo < 0) cumNo = 0;

      final points = <PricePoint>[];
      double runningYes = cumYes;
      double runningNo = cumNo;

      for (final log in logs) {
        final amount = (log['amount'] as BigInt).toDouble() / 1e18;
        if (log['outcome'] == 0) {
          runningYes += amount;
        } else {
          runningNo += amount;
        }

        final total = runningYes + runningNo;
        final double yesPrice = total > 0 ? (runningYes / total) * 100 : 50.0;

        final blockNum = log['blockNumber'] as String;
        final timestamp = await ContractService.getBlockTimestamp(rpcUrl, blockNum);
        if (timestamp > 0) {
          points.add(PricePoint(timestamp: timestamp, yesPrice: yesPrice, noPrice: 100 - yesPrice));
        }
      }

      return points;
    } catch (e) {
      return [];
    }
  }
}
