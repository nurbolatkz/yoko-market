import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yokomarket/main.dart';
import 'package:yokomarket/models/product.dart';
import 'package:yokomarket/models/product_category.dart';
import 'package:yokomarket/providers/market_provider.dart';
import 'package:yokomarket/services/catalog_api.dart';
import 'package:yokomarket/widgets/product_image.dart';

void main() {
  test('Product parses the confirmed Django catalog fields', () {
    final product = Product.fromApiJson({
      'id': 'api-id',
      'name': 'YokoSun Premium',
      'description': 'Описание',
      'size': 'M',
      'price': 5990,
      'promo_price': 5490,
      'category': 'Подгузники',
      'stock_qty': 12,
      'is_active': true,
      'rating': 4.8,
      'hero_url': '/media/product.png',
      'images': <dynamic>[],
    });

    expect(product.id, 'api-id');
    expect(product.title, 'YokoSun Premium');
    expect(product.price, 5490);
    expect(product.packageInfo, 'M');
    expect(product.inStock, isTrue);
    expect(product.stockQuantity, 12);
    expect(product.imageUrl, contains('/media/product.png'));
  });

  testWidgets('YokoMarket app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await _pumpTestApp(tester);

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('YokoSun'), findsWidgets);
  });

  testWidgets('Home and Catalog use the same product image URL', (
    WidgetTester tester,
  ) async {
    await _pumpTestApp(tester);

    final homeScroll = find.byKey(const Key('home-scroll'));
    for (var index = 0; index < 4; index++) {
      await tester.drag(homeScroll, const Offset(0, -250));
      await tester.pump();
      if (find.byKey(const Key('home-product-image-p1')).evaluate().isNotEmpty) {
        break;
      }
    }
    final homeImage = tester.widget<ProductImage>(
      find.byKey(const Key('home-product-image-p1')),
    );

    await tester.tap(find.text('Каталог'));
    await tester.pumpAndSettle();

    final catalogImage = tester.widget<ProductImage>(
      find.byKey(const Key('catalog-product-image-p1')),
    );
    expect(homeImage.imageUrl, isNotEmpty);
    expect(catalogImage.imageUrl, homeImage.imageUrl);
  });

  testWidgets('Home scroll reaches the last product and returns to top', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpTestApp(tester);

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

    await _pumpTestApp(tester);
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
    await tester.pumpAndSettle();
    expect(find.text('Товары не найдены'), findsOneWidget);

    await tester.tap(find.text('Сбросить фильтры'));
    await tester.pumpAndSettle();
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
    await _pumpTestApp(tester);

    await tester.tap(find.text('Салфетки'));
    await tester.pumpAndSettle();

    expect(find.text('Каталог'), findsWidgets);
    expect(find.text('1 товар'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpTestApp(WidgetTester tester) async {
  await tester.pumpWidget(
    YokoMarketApp(
      marketProvider: MarketProvider(
        catalogDataSource: _FakeCatalogDataSource(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeCatalogDataSource implements CatalogDataSource {
  final List<Product> _products = List.generate(8, (index) {
    final number = index + 1;
    final isWipes = number == 4;
    return Product(
      id: 'p$number',
      title: number == 8
          ? 'Одноразовые пеленки'
          : isWipes
          ? 'Влажные салфетки Aura'
          : 'Подгузники YokoSun $number',
      description: 'Тестовый товар API',
      price: 1000 + number * 100,
      imageUrl: number == 1 ? 'https://example.test/product-1.png' : '',
      category: isWipes ? 'Салфетки' : 'Подгузники',
      packageInfo: '$number шт',
      inStock: number != 8,
      stockQuantity: number == 8 ? 0 : number,
    );
  });

  @override
  Future<List<ProductCategory>> getCategories() async => const [
    ProductCategory(id: '1', name: 'Подгузники'),
    ProductCategory(id: '2', name: 'Салфетки'),
  ];

  @override
  Future<List<Product>> getProducts({
    String? category,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    return _products.where((product) {
      final categoryMatches = category == null || product.category == category;
      final searchMatches =
          search == null ||
          search.isEmpty ||
          product.title.toLowerCase().contains(search.toLowerCase());
      return categoryMatches && searchMatches;
    }).toList();
  }
}
