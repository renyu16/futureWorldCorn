import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

class NewsItem {
  final String title;
  final String source;
  final String link;
  final DateTime published;
  const NewsItem({required this.title, required this.source, required this.link, required this.published});
}

class NewsService {
  static const _cacheDuration = Duration(minutes: 5);
  static final Map<String, (List<NewsItem>, DateTime)> _cache = {};

  static List<String> defaultKeywords = const ['crypto', '比特币', '以太坊', '美联储', 'fed'];

  static Future<List<NewsItem>> fetch(List<String> keywords) async {
    final key = keywords.join(',');
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.$2) < _cacheDuration) {
      return cached.$1;
    }
    final results = <NewsItem>[];
    for (final kw in keywords) {
      try {
        final uri = Uri.parse(
            'https://news.google.com/rss/search?q=${Uri.encodeQueryComponent(kw)}&hl=zh-CN&gl=CN&ceid=CN:zh-Hans');
        final res = await http.get(uri).timeout(const Duration(seconds: 10));
        if (res.statusCode != 200) continue;
        results.addAll(parseRss(res.body));
      } catch (_) {}
    }
    final seen = <String>{};
    final unique = <NewsItem>[];
    for (final n in results) {
      if (seen.add(n.title)) unique.add(n);
    }
    unique.sort((a, b) => b.published.compareTo(a.published));
    final top = unique.length > 20 ? unique.sublist(0, 20) : unique;
    if (top.isNotEmpty) _cache[key] = (top, DateTime.now());
    return top;
  }

  static List<NewsItem> parseRss(String body) {
    final items = <NewsItem>[];
    try {
      final doc = XmlDocument.parse(body);
      for (final item in doc.findAllElements('item')) {
        final title = item.findElements('title').firstOrNull?.innerText ?? '';
        final link = item.findElements('link').firstOrNull?.innerText ?? '';
        final pubStr = item.findElements('pubDate').firstOrNull?.innerText ?? '';
        final source = item.findElements('source').firstOrNull?.innerText ?? '新闻';
        DateTime? published;
        try { published = DateTime.parse(pubStr); } catch (_) {}
        if (title.isEmpty) continue;
        items.add(NewsItem(
          title: title.replaceAll(RegExp(r'<[^>]+>'), ''),
          source: source,
          link: link,
          published: published ?? DateTime.now(),
        ));
      }
    } catch (_) {}
    return items;
  }

  static String relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }
}
