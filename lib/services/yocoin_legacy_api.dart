import 'package:dio/dio.dart';

import 'api_client.dart';

/// Raw-JSON access for the current YoCoin screens, which still render the
/// legacy rules shape and the live bonus history from the real backend.
///
/// New screens use the typed [LoyaltyApi] / [WalletApi] instead. Delete this
/// once YoCoinScreen and YoCoinHistoryScreen move to the redesign.
class YoCoinLegacyApi {
  YoCoinLegacyApi({Dio? dio}) : _dio = dio ?? ApiClient.create();

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
