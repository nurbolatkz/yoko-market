import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/product.dart';
import '../models/product_category.dart';

abstract interface class CatalogDataSource {
  Future<List<ProductCategory>> getCategories();

  Future<List<Product>> getProducts({
    String? category,
    String? search,
    int limit = 50,
    int offset = 0,
  });
}

class CatalogApi implements CatalogDataSource {
  CatalogApi({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
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
}

List<Map<String, dynamic>> _listOfMaps(dynamic data) {
  if (data is! List) return const [];
  return data.whereType<Map<String, dynamic>>().toList();
}
