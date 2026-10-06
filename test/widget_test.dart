import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yokomarket/main.dart';

void main() {
  testWidgets('YokoMarket app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const YokoMarketApp());

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('YokoSun'), findsWidgets);
  });

  testWidgets('Home scroll reaches the last product and returns to top', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const YokoMarketApp());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Главная'), findsOneWidget);
    expect(find.text('Подгузники'), findsOneWidget);

    final homeScroll = find.byKey(const Key('home-scroll'));
    for (var index = 0; index < 6; index++) {
      await tester.drag(homeScroll, const Offset(0, -300));
      await tester.pump();
    }

    expect(find.textContaining('Aura'), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (var index = 0; index < 6; index++) {
      await tester.drag(homeScroll, const Offset(0, 300));
      await tester.pump();
    }

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('YokoSun'), findsWidgets);
    expect(find.textContaining('Aura'), findsNothing);
  });
}
