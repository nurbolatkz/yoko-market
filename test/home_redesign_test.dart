import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yokomarket/main.dart';
import 'package:yokomarket/models/banner_item.dart';
import 'package:yokomarket/preview/preview_fixtures.dart';
import 'package:yokomarket/providers/market_provider.dart';
import 'package:yokomarket/screens/cart_screen.dart';
import 'package:yokomarket/screens/favorites_screen.dart';
import 'package:yokomarket/screens/product_catalog_screen.dart';
import 'package:yokomarket/screens/profile_screen.dart';
import 'package:yokomarket/widgets/home/home_hero_banner.dart';
import 'package:yokomarket/widgets/home/home_info_tiles.dart';

Widget _wrap(Widget child, {double scale = 1}) => MaterialApp(
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  ),
);

const _ready = BannerItem(
  id: 'r1',
  title: 'Нежная забота каждый день',
  subtitle: 'Подгузники и трусики',
  bgColor: '#EDE8FA',
  imageUrl: 'https://example.test/banner.webp',
);

const _illustration = BannerItem(
  id: 'i1',
  title: 'Забота о самых важных',
  subtitle: 'Подгузники и уход',
  bgColor: '#FBE1CE',
  imageUrl: 'asset:assets/preview/hero_mother_baby.webp',
  imageKind: 'illustration',
  actionType: 'category',
  actionValue: 'Подгузники',
  actionLabel: 'К покупкам',
);

void main() {
  // Real app font, so label-fit checks measure what users see.
  setUpAll(() async {
    final loader = FontLoader('NunitoSans');
    for (final w in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/NunitoSans_$w.ttf').readAsBytesSync(),
          ),
        ),
      );
    }
    await loader.load();
  });

  group('Hero banner formats', () {
    testWidgets('ready banner: Flutter draws no title over the image', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          HomeHeroCarousel(
            banners: const [_ready],
            onOpen: (_) {},
            onAction: (_) {},
          ),
        ),
      );
      expect(find.text('Нежная забота каждый день'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      // Exactly the backend aspect (1942×809 ≈ 2.4) — no crop of baked text.
      final size = tester.getSize(find.byType(PageView));
      expect(size.width / size.height, closeTo(kHeroBannerAspect, 0.01));
    });

    testWidgets('illustration banner: title + CTA only with a real action', (
      tester,
    ) async {
      String? opened;
      await tester.pumpWidget(
        _wrap(
          HomeHeroCarousel(
            banners: const [_illustration],
            onOpen: (_) {},
            onAction: (b) => opened = b.actionValue,
          ),
        ),
      );
      expect(find.text('Забота о самых важных'), findsOneWidget);
      await tester.tap(find.text('К покупкам'));
      expect(opened, 'Подгузники');

      const noAction = BannerItem(
        id: 'i2',
        title: 'Без действия',
        bgColor: '#FBE1CE',
        imageUrl: 'asset:assets/preview/hero_mother_baby.webp',
        imageKind: 'illustration',
      );
      await tester.pumpWidget(
        _wrap(
          HomeHeroCarousel(
            banners: const [noAction],
            onOpen: (_) {},
            onAction: (_) {},
          ),
        ),
      );
      expect(find.text('Без действия'), findsOneWidget);
      expect(find.text('К покупкам'), findsNothing);
    });

    testWidgets('banner without image is a compact card, not a large fill', (
      tester,
    ) async {
      const textOnly = BannerItem(id: 't', title: 'Акция', bgColor: '#F25A1D');
      await tester.pumpWidget(
        _wrap(
          HomeHeroCarousel(
            banners: const [textOnly],
            onOpen: (_) {},
            onAction: (_) {},
          ),
        ),
      );
      expect(tester.getSize(find.byType(PageView)).height, lessThan(110));
    });

    testWidgets('empty list renders nothing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HomeHeroCarousel(banners: const [], onOpen: (_) {}, onAction: (_) {}),
        ),
      );
      expect(find.byType(PageView), findsNothing);
    });
  });

  group('Info tiles', () {
    testWidgets('unconfirmed delivery threshold shows no number', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          HomeInfoTiles(
            maxCashbackPercent: 10,
            freeDeliveryFrom: null,
            onBonusTap: () {},
            onDeliveryTap: () {},
          ),
        ),
      );
      expect(find.text('Кэшбэк до 10%'), findsOneWidget);
      expect(find.text('Условия доставки'), findsOneWidget);
      expect(find.textContaining('₸'), findsNothing);
    });

    testWidgets('no cashback maximum from API → no percent', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HomeInfoTiles(
            maxCashbackPercent: null,
            freeDeliveryFrom: null,
            onBonusTap: () {},
            onDeliveryTap: () {},
          ),
        ),
      );
      expect(find.textContaining('%'), findsNothing);
    });
  });

  group('Bottom navigation', () {
    Future<void> pumpApp(WidgetTester tester, Size size, double scale) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
          ),
          child: YokoMarketApp(
            marketProvider: MarketProvider(
              catalogDataSource: PreviewCatalogDataSource(),
              homeInfoLoader: previewHomeInfo,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('each tab opens its screen in the new order', (tester) async {
      await pumpApp(tester, const Size(390, 844), 1);
      final expected = <String, Finder>{
        'Каталог': find.byType(ProductCatalogScreen),
        'Избранное': find.byType(FavoritesScreen),
        'Корзина': find.byType(CartScreen),
        'Профиль': find.byType(ProfileScreen),
        'Главная': find.byKey(const Key('home-scroll')),
      };
      for (final entry in expected.entries) {
        await tester.tap(find.byKey(Key('nav-${entry.key}')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(entry.value, findsOneWidget, reason: entry.key);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('all labels at 390 dp; selected-only at 360 dp × 1.5', (
      tester,
    ) async {
      await pumpApp(tester, const Size(390, 844), 1);
      for (final l in [
        'Главная',
        'Каталог',
        'Избранное',
        'Корзина',
        'Профиль',
      ]) {
        expect(
          find.descendant(
            of: find.byKey(Key('nav-$l')),
            matching: find.text(l),
          ),
          findsOneWidget,
          reason: l,
        );
      }

      await pumpApp(tester, const Size(360, 740), 1.5);
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byKey(const Key('nav-Главная')),
          matching: find.text('Главная'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('nav-Избранное')),
          matching: find.text('Избранное'),
        ),
        findsNothing,
      );
      // Label keeps the user's text size (not shrunk to fit).
      final label = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('nav-Главная')),
          matching: find.text('Главная'),
        ),
      );
      expect(label.textScaler, isNull);
    });
  });

  group('UI_PREVIEW fixtures', () {
    test('real backend IDs and assortment; demo banners are marked', () async {
      final src = PreviewCatalogDataSource();
      final home = (await src.getCategories()).where((c) => c.setHome).take(4);
      expect(home.map((c) => c.name), [
        'Подгузники',
        'Вкладыши и пелёнки',
        'Салфетки',
        'Ватные палочки',
      ]);
      expect(home.first.id, '57c9c012-4e60-495c-8833-96d7c17ec5b0');
      expect(home.every((c) => c.imageUrl != null), isTrue);

      final products = await src.getProducts(limit: 50);
      expect(products, hasLength(24));
      expect(products.every((p) => p.imageUrl.startsWith('https://')), isTrue);

      final banners = await src.getBanners();
      expect(banners.first.isIllustration, isTrue);
      expect(banners.where((b) => b.isSpecialOffer), hasLength(2));
      expect(
        banners.where((b) => !b.isSpecialOffer && !b.isIllustration),
        hasLength(3), // the real ready banners from /banners
      );
      expect(
        banners
            .where((b) => b.isSpecialOffer || b.isIllustration)
            .every((b) => b.id.startsWith('preview-')),
        isTrue,
      );
    });
  });
}
