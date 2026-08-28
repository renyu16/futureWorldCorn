import '../providers/market_provider.dart';
import 'categories.dart';

enum SortKey { newest, pool, deadline, odds }
enum StatusFilter { all, active, pending, resolved, cancelled }

class FilterState {
  final String search;
  final SortKey sort;
  final StatusFilter status;
  final String category;

  const FilterState({
    this.search = '',
    this.sort = SortKey.newest,
    this.status = StatusFilter.all,
    this.category = 'all',
  });

  FilterState copyWith({
    String? search,
    SortKey? sort,
    StatusFilter? status,
    String? category,
  }) {
    return FilterState(
      search: search ?? this.search,
      sort: sort ?? this.sort,
      status: status ?? this.status,
      category: category ?? this.category,
    );
  }
}

List<MarketData> filterAndSort(List<MarketData> markets, FilterState filters) {
  var filtered = List<MarketData>.from(markets);
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  if (filters.status != StatusFilter.all) {
    switch (filters.status) {
      case StatusFilter.pending:
        filtered = filtered.where((m) => m.status == 0 && m.deadline <= now).toList();
        break;
      case StatusFilter.active:
        filtered = filtered.where((m) => m.status == 0 && m.deadline > now).toList();
        break;
      case StatusFilter.resolved:
        filtered = filtered.where((m) => m.status == 1).toList();
        break;
      case StatusFilter.cancelled:
        filtered = filtered.where((m) => m.status == 2).toList();
        break;
      case StatusFilter.all:
        break;
    }
  }

  if (filters.category != 'all') {
    filtered = filtered.where((m) => classifyQuestion(m.question) == filters.category).toList();
  }

  if (filters.search.isNotEmpty) {
    final q = filters.search.toLowerCase();
    filtered = filtered.where((m) => m.question.toLowerCase().contains(q)).toList();
  }

  switch (filters.sort) {
    case SortKey.newest:
      filtered.sort((a, b) => b.id.compareTo(a.id));
      break;
    case SortKey.pool:
      filtered.sort((a, b) => b.totalPool.compareTo(a.totalPool));
      break;
    case SortKey.deadline:
      filtered.sort((a, b) => a.deadline.compareTo(b.deadline));
      break;
    case SortKey.odds:
      filtered.sort((a, b) => b.yesPct.compareTo(a.yesPct));
      break;
  }

  return filtered;
}
