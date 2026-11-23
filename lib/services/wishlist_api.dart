import 'package:dio/dio.dart';

import 'api_client.dart';

/// Server-side wishlist (`/wishlist/*`, Bearer).
class WishlistApi {
  WishlistApi({Dio? dio}) : _dio = dio ?? ApiClient.create();

  final Dio _dio;

  /// Merges [productIds] into the server list and returns the merged IDs.
  Future<Set<String>> sync(String token, List<String> productIds) async {
    final resp = await _dio.post<dynamic>(
      '/wishlist/sync',
      data: {'product_ids': productIds},
      options: ApiClient.bearer(token),
    );
    final data = resp.data as Map<String, dynamic>;
    return (data['product_ids'] as List).cast<String>().toSet();
  }

  Future<void> add(String token, String productId) => _dio.post<dynamic>(
    '/wishlist/$productId',
    options: ApiClient.bearer(token),
  );

  Future<void> remove(String token, String productId) => _dio.delete<dynamic>(
    '/wishlist/$productId',
    options: ApiClient.bearer(token),
  );
}
