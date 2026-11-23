import 'package:dio/dio.dart';

import 'api_client.dart';

/// Loyalty endpoints. Returns raw JSON for now — the screens own the models.
/// TODO(loyalty): typed `LoyaltyRules` + Http/Mock implementations per
/// AGENTS.md §9 (`MOCK_LOYALTY`).
class LoyaltyApi {
  LoyaltyApi({Dio? dio}) : _dio = dio ?? ApiClient.create();

  final Dio _dio;

  /// `GET /loyalty/rules` (public).
  Future<Map<String, dynamic>> getRulesJson() async {
    final resp = await _dio.get<dynamic>('/loyalty/rules');
    return resp.data as Map<String, dynamic>;
  }

  /// `GET /mobile/bonus-history` → `{balance, total, items[]}`.
  Future<Map<String, dynamic>> getBonusHistoryJson({
    required String token,
    required int offset,
    required int limit,
  }) async {
    final resp = await _dio.get<dynamic>(
      '/mobile/bonus-history',
      queryParameters: {'offset': offset, 'limit': limit},
      options: ApiClient.bearer(token),
    );
    return resp.data as Map<String, dynamic>;
  }
}
