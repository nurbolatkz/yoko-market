import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/banner_item.dart';
import '../models/product.dart';
import '../models/product_category.dart';

class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.size,
    required this.price,
    this.originalPrice,
    required this.stockQty,
    this.heroUrl,
  });

  final String id;
  final String size;
  final double price;
  final double? originalPrice;
  final int stockQty;
  final String? heroUrl;

  bool get inStock => stockQty > 0;

  factory ProductVariant.fromJson(Map<String, dynamic> j) {
    final salePrice = _asNullableDouble(j['promo_price'] ?? j['sale_price']);
    final basePrice = _asDouble(j['price']);
    final rawUrl = j['hero_url'];
    return ProductVariant(
      id: '${j['id']}',
      size: j['size'] as String? ?? 'ONE',
      price: salePrice ?? basePrice,
      originalPrice: (salePrice != null && salePrice < basePrice) ? basePrice : null,
      stockQty: _asInt(j['stock_qty']),
      heroUrl: rawUrl is String && rawUrl.isNotEmpty ? rawUrl : null,
    );
  }
}

abstract interface class CatalogDataSource {
  Future<List<ProductCategory>> getCategories();

  Future<List<Product>> getProducts({
    String? category,
    String? search,
    int limit = 50,
    int offset = 0,
  });

  Future<List<BannerItem>> getBanners();

  Future<Map<String, dynamic>> getBannerById(String id);

  Future<({Product product, List<ProductVariant> variants})> getProductById(String id);
}

class CatalogApi implements CatalogDataSource {
  CatalogApi({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              responseType: ResponseType.json,
            ),
          );

  final Dio _dio;

  @override
  Future<List<ProductCategory>> getCategories() async {
    final response = await _dio.get<dynamic>('/categories/public');
    // Only top-level category names are valid as ?category= filter values.
    // Subcategory names live in Product.subcategory, not Product.category,
    // so flattening them into the filter list would produce empty results.
    return _listOfMaps(response.data)
        .map(ProductCategory.fromJson)
        .where((category) => category.name.isNotEmpty)
        .toList();
  }

  @override
  Future<List<Product>> getProducts({
    String? category,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _dio.get<dynamic>(
      '/products',
      queryParameters: {
        if (category != null && category.isNotEmpty) 'category': category,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'sort': 'popular',
        'limit': limit,
        'offset': offset,
      },
    );

    return _listOfMaps(response.data).map(Product.fromApiJson).toList();
  }

  @override
  Future<List<BannerItem>> getBanners() async {
    final response = await _dio.get<dynamic>('/banners');
    return _listOfMaps(response.data).map(BannerItem.fromJson).toList();
  }

  @override
  Future<Map<String, dynamic>> getBannerById(String id) async {
    final response = await _dio.get<dynamic>('/banners/$id');
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('unexpected_response');
  }

  @override
  Future<({Product product, List<ProductVariant> variants})> getProductById(String id) async {
    final response = await _dio.get<dynamic>('/products/$id');
    final json = response.data as Map<String, dynamic>;
    final product = Product.fromApiJson(json);
    final variants = (json['variants'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ProductVariant.fromJson)
        .toList();
    return (product: product, variants: variants);
  }
}

List<Map<String, dynamic>> _listOfMaps(dynamic data) {
  if (data is! List) return const [];
  return data.whereType<Map<String, dynamic>>().toList();
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

double? _asNullableDouble(dynamic value) {
  if (value == null) return null;
  return _asDouble(value);
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}
