import 'package:flutter_test/flutter_test.dart';
import 'package:yokomarket/main.dart';

void main() {
  testWidgets('YokoMarket app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const YokoMarketApp());

    expect(find.text('Популярные бренды'), findsOneWidget);
    expect(find.text('YokoSun'), findsWidgets);
  });
}
