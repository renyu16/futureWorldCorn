import 'package:flutter_test/flutter_test.dart';
import 'package:future_world_corn_mobile/services/news_service.dart';

void main() {
  group('NewsService.parseRss', () {
    test('parses valid RSS XML', () {
      const xml = '''
      <rss version="2.0"><channel>
        <item>
          <title>比特币突破新高</title>
          <link>https://example.com/1</link>
          <pubDate>Fri, 28 Aug 2026 10:00:00 GMT</pubDate>
          <source>CoinDesk</source>
        </item>
      </channel></rss>''';
      final items = NewsService.parseRss(xml);
      expect(items.length, 1);
      expect(items.first.title, '比特币突破新高');
      expect(items.first.source, 'CoinDesk');
    });

    test('returns empty for broken XML', () {
      expect(NewsService.parseRss('not xml at all'), isEmpty);
    });

    test('relativeTime formats', () {
      final now = DateTime.now();
      expect(NewsService.relativeTime(now.subtract(const Duration(minutes: 1))), '1分钟前');
      expect(NewsService.relativeTime(now.subtract(const Duration(hours: 2))), '2小时前');
    });
  });
}
