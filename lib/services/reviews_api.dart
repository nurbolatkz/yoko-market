import 'package:dio/dio.dart';

import 'api_client.dart';

/// Product reviews (`/products/{id}/reviews`).
class ReviewsApi {
  ReviewsApi({Dio? dio}) : _dio = dio ?? ApiClient.create();

  final Dio _dio;

  Future<List<Map<String, dynamic>>> list(String productId) async {
    final resp = await _dio.get<dynamic>('/products/$productId/reviews');
    final raw = resp.data;
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  /// Posts a review. Guests ([token] == null) are sent as "Покупатель".
  /// Returns true when the backend says the user had already reviewed.
  Future<bool> submit(
    String productId, {
    required int rating,
    String? text,
    String? token,
  }) async {
    final resp = await _dio.post<dynamic>(
      '/products/$productId/reviews',
      data: {
        if (token == null) 'author_name': 'Покупатель',
        'rating': rating,
        if (text != null && text.isNotEmpty) 'text': text,
      },
      options: token != null ? ApiClient.bearer(token) : null,
    );
    final data = resp.data;
    return data is Map && data['already_reviewed'] == true;
  }
}
