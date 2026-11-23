import 'package:dio/dio.dart';

import 'api_client.dart';

/// FAQ / support tree (`GET /support/tree`, public).
class SupportApi {
  SupportApi({Dio? dio}) : _dio = dio ?? ApiClient.create();

  final Dio _dio;

  /// Flat list of tree nodes; the screen assembles the hierarchy.
  Future<List<Map<String, dynamic>>> getTree() async {
    final resp = await _dio.get<dynamic>('/support/tree');
    final raw = resp.data;
    if (raw is! List) throw const FormatException('unexpected_response');
    return raw.whereType<Map<String, dynamic>>().toList();
  }
}
