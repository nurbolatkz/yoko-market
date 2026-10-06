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

  testWidgets('Catalog filters, scrolls, and updates cart on a small phone', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const YokoMarketApp());
    await tester.tap(find.text('Каталог'));
    await tester.pump();

    expect(find.text('8 товаров'), findsOneWidget);
    expect(find.text('Фото скоро'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('add-p1')));
    await tester.pump();
    expect(find.text('1'), findsWidgets);

    await tester.enterText(
      find.byKey(const Key('catalog-search')),
      'нет такого',
    );
    await tester.pump();
    expect(find.text('Товары не найдены'), findsOneWidget);

    await tester.tap(find.text('Сбросить фильтры'));
    await tester.pump();
    expect(find.text('8 товаров'), findsOneWidget);

    final grid = find.byKey(const Key('catalog-grid'));
    for (var index = 0; index < 4; index++) {
      await tester.drag(grid, const Offset(0, -300));
      await tester.pump();
    }

    expect(find.textContaining('Одноразовые пеленки'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home category opens Catalog with the category selected', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const YokoMarketApp());

    await tester.tap(find.text('Салфетки'));
    await tester.pump();

    expect(find.text('Каталог'), findsWidgets);
    expect(find.text('1 товар'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
