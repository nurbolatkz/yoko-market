import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yokomarket/services/api_client.dart';

/// Fake transport: answers 401 unless the request carries [validToken].
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.validToken});

  String validToken;
  final List<String?> seenAuth = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final auth = options.headers['Authorization'] as String?;
    seenAuth.add(auth);
    final ok = options.path.startsWith('/public') ||
        auth == 'Bearer $validToken';
    return ResponseBody.fromString(
      jsonEncode(ok ? {'ok': true} : {'detail': 'unauthorized'}),
      ok ? 200 : 401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _FakeAdapter adapter;
  late Dio dio;
  late int refreshCalls;
  String? stored;
  String? refreshResult;

  setUp(() {
    adapter = _FakeAdapter(validToken: 'new');
    refreshCalls = 0;
    stored = 'old';
    refreshResult = 'new';
    dio = Dio(BaseOptions(baseUrl: 'https://test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(
      AuthInterceptor(
        dio: dio,
        refresher: () async {
          refreshCalls++;
          stored = refreshResult;
          return refreshResult;
        },
        reader: () async => stored,
      ),
    );
  });

  test('401 with bearer → refreshes once and retries with new token',
      () async {
    final resp = await dio.get<dynamic>(
      '/my-orders',
      options: ApiClient.bearer('old'),
    );

    expect(resp.statusCode, 200);
    expect(refreshCalls, 1);
    expect(adapter.seenAuth, ['Bearer old', 'Bearer new']);
  });

  test('token already refreshed by another request → retries without '
      'rotating the refresh token again', () async {
    stored = 'new'; // a parallel request refreshed first

    final resp = await dio.get<dynamic>(
      '/my-orders',
      options: ApiClient.bearer('old'),
    );

    expect(resp.statusCode, 200);
    expect(refreshCalls, 0);
    expect(adapter.seenAuth.last, 'Bearer new');
  });

  test('refresh fails → original 401 is surfaced', () async {
    refreshResult = null;

    await expectLater(
      dio.get<dynamic>('/my-orders', options: ApiClient.bearer('old')),
      throwsA(
        isA<DioException>()
            .having((e) => e.response?.statusCode, 'status', 401),
      ),
    );
    expect(refreshCalls, 1);
    expect(adapter.seenAuth, ['Bearer old']);
  });

  test('retry still 401 → no loop, refresh attempted only once', () async {
    adapter.validToken = 'never';

    await expectLater(
      dio.get<dynamic>('/my-orders', options: ApiClient.bearer('old')),
      throwsA(isA<DioException>()),
    );
    expect(refreshCalls, 1);
    expect(adapter.seenAuth.length, 2);
  });

  test('401 without Authorization header → no refresh', () async {
    await expectLater(
      dio.get<dynamic>('/my-orders'),
      throwsA(isA<DioException>()),
    );
    expect(refreshCalls, 0);
  });

  test('401 on /auth/* → no refresh (avoids recursion)', () async {
    await expectLater(
      dio.post<dynamic>('/auth/logout', options: ApiClient.bearer('old')),
      throwsA(isA<DioException>()),
    );
    expect(refreshCalls, 0);
  });

  test('public request succeeds untouched', () async {
    final resp = await dio.get<dynamic>('/public/banners');
    expect(resp.statusCode, 200);
    expect(refreshCalls, 0);
  });
}
