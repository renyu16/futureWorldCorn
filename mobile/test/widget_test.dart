import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:future_world_corn_mobile/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('预测大师'), findsOneWidget);
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('投资'), findsOneWidget);
    expect(find.text('治理'), findsOneWidget);
    expect(find.text('更多'), findsOneWidget);
  });
}