import 'dart:convert';

import '../models/banner_item.dart';
import '../models/product.dart';
import '../models/product_category.dart';
import '../providers/market_provider.dart';
import '../services/catalog_api.dart';
import 'preview_catalog_snapshot.dart';

/// UI_PREVIEW-only data for Home (`--dart-define=UI_PREVIEW=true`).
///
/// - Categories, products, prices, photos and the three ready banners are a
///   snapshot of the real public API (see preview_catalog_snapshot.dart).
/// - The illustration hero banner and the two «Специальные предложения»
///   cards are **fixtures** built from the client's illustrations; their
///   badges («До −30%», «2+1») are demo values, not backend promotions.
///
/// Production never uses this: main.dart wires it only when
/// `AppConfig.uiPreview` is true, and there is no production fallback.
class PreviewCatalogDataSource implements CatalogDataSource {
  PreviewCatalogDataSource();

  late final List<ProductCategory> _categories =
      (jsonDecode(kPreviewCategoriesJson) as List)
          .cast<Map<String, dynamic>>()
          .map(ProductCategory.fromJson)
          .toList();

  late final List<Map<String, dynamic>> _productJson =
      (jsonDecode(kPreviewProductsJson) as List).cast<Map<String, dynamic>>();

  late final List<Product> _products = _productJson
      .map(Product.fromApiJson)
      .toList();

  late final List<Map<String, dynamic>> _readyBanners = (jsonDecode(
    kPreviewReadyBannersJson,
  ) as List).cast<Map<String, dynamic>>();

  /// Fixture banners (client illustrations; values are demo data).
  static const _fixtureBanners = <Map<String, dynamic>>[
    {
      'id': 'preview-hero-illustration',
      'title': 'Забота о самых важных',
      'subtitle': 'Подгузники, трусики и уход для малышей',
      'bg_color': '#FBE1CE',
      'image_url': 'asset:assets/preview/hero_mother_baby.webp',
      'image_kind': 'illustration',
      'action_type': 'category',
      'action_value': 'Подгузники',
      'action_label': 'К покупкам',
      'full_description':
          'Демо-баннер UI_PREVIEW: иллюстрация без текста, заголовок и '
          'кнопку рисует приложение.',
    },
    {
      'id': 'preview-offer-diapers',
      'title': 'Выгода на подгузники',
      'subtitle': 'Подгузники, трусики и не только',
      'bg_color': '#FCE9DF',
      'discount_badge': 'До −30%',
      'placement': 'special',
      'illustration_url': 'asset:assets/preview/offer_set_diapers.webp',
      'action_type': 'category',
      'action_value': 'Подгузники',
      'full_description': 'Демо-акция UI_PREVIEW.',
    },
    {
      'id': 'preview-offer-hygiene',
      'title': 'Уход за малышом',
      'subtitle': 'Собери выгодный набор',
      'bg_color': '#FCE9DF',
      'badge': '2+1',
      'placement': 'special',
      'illustration_url': 'asset:assets/preview/offer_set_hygiene.webp',
      'action_type': 'category',
      'action_value': 'Салфетки',
      'full_description': 'Демо-акция UI_PREVIEW.',
    },
  ];

  @override
  Future<List<ProductCategory>> getCategories() async => _categories;

  @override
  Future<List<Product>> getProducts({
    String? category,
    String? search,
    int limit = 50,
    int offset = 0,
    String sort = 'popular',
  }) async {
    Iterable<Product> list = _products;
    if (sort == 'sales') list = _products.reversed;
    if (sort == 'new') list = _products.skip(8);
    if (category != null && category.isNotEmpty && category != 'All') {
      list = list.where((p) => p.category == category);
    }
    final q = search?.trim().toLowerCase() ?? '';
    if (q.isNotEmpty) {
      list = list.where((p) => p.title.toLowerCase().contains(q));
    }
    return list.skip(offset).take(limit).toList();
  }

  @override
  Future<List<BannerItem>> getBanners() async => [
    BannerItem.fromJson(_fixtureBanners.first),
    ..._readyBanners.map(BannerItem.fromJson),
    ..._fixtureBanners.skip(1).map(BannerItem.fromJson),
  ];

  @override
  Future<Map<String, dynamic>> getBannerById(String id) async =>
      [..._fixtureBanners, ..._readyBanners].firstWhere(
        (b) => b['id'] == id,
        orElse: () => throw Exception('banner_not_found'),
      );

  @override
  Future<({Product product, List<ProductVariant> variants})> getProductById(
    String id,
  ) async {
    final json = _productJson.firstWhere(
      (p) => p['id'] == id,
      orElse: () => throw Exception('not_found'),
    );
    return (product: Product.fromApiJson(json), variants: <ProductVariant>[]);
  }
}

/// Home info cards in preview: cashback = real programme maximum from the
/// snapshot; delivery = real /settings/delivery value, shown here only as a
/// labelled preview value.
Future<HomeInfo> previewHomeInfo() async => (
  maxCashbackPercent: kPreviewLoyaltyMaxPercent,
  freeDeliveryFrom: kPreviewFreeDeliveryFrom,
);
