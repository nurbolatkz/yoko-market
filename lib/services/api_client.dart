import 'package:dio/dio.dart';

import '../config/app_config.dart';

/// Returns a fresh access token after a successful refresh, or null when the
/// session can't be renewed (the caller then surfaces the 401 as-is).
typedef TokenRefresher = Future<String?> Function();

/// Reads the access token currently in storage.
typedef TokenReader = Future<String?> Function();

/// Single place that builds every [Dio] the app uses.
///
/// All instances share [AuthInterceptor], so any request that carried a
/// `Authorization: Bearer …` header and got a 401 is transparently refreshed
/// once and retried with the new token. Screens and services therefore never
/// need their own refresh/retry logic.
///
/// [AuthService] keeps its own interceptor-free Dio for `/auth/*` calls so a
/// failing refresh can never recurse into itself.
abstract final class ApiClient {
  static TokenRefresher? _refresher;
  static TokenReader? _reader;

  /// Wired once by [AuthProvider] at startup.
  static void configure({
    required TokenRefresher refresher,
    required TokenReader reader,
  }) {
    _refresher = refresher;
    _reader = reader;
  }

  /// Builds a Dio pointed at [AppConfig.apiBaseUrl] with the auth interceptor.
  static Dio create({Duration timeout = const Duration(seconds: 8)}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: timeout,
        receiveTimeout: timeout,
        responseType: ResponseType.json,
      ),
    );
    dio.interceptors.add(
      AuthInterceptor(
        dio: dio,
        refresher: () => _refresher?.call() ?? Future.value(null),
        reader: () => _reader?.call() ?? Future.value(null),
      ),
    );
    return dio;
  }

  /// Convenience for request options carrying a bearer token.
  static Options bearer(String token, {Map<String, dynamic>? extraHeaders}) =>
      Options(headers: {'Authorization': 'Bearer $token', ...?extraHeaders});
}

/// On a 401 for an authenticated request: refresh once, retry once.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.dio,
    required this.refresher,
    required this.reader,
  });

  final Dio dio;
  final TokenRefresher refresher;
  final TokenReader reader;

  static const _retriedKey = 'auth_retried';
  static const _authHeader = 'Authorization';
  static const _bearer = 'Bearer ';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final req = err.requestOptions;
    final sentAuth = req.headers[_authHeader];
    final shouldRefresh =
        err.response?.statusCode == 401 &&
        sentAuth is String &&
        sentAuth.startsWith(_bearer) &&
        req.extra[_retriedKey] != true &&
        !req.path.startsWith('/auth/');
    if (!shouldRefresh) return handler.next(err);

    try {
      // Another request may have refreshed already while this one was in
      // flight — reuse that token instead of rotating the refresh token again.
      final sentToken = sentAuth.substring(_bearer.length);
      final stored = await reader();
      final fresh = (stored != null && stored != sentToken)
          ? stored
          : await refresher();
      if (fresh == null) return handler.next(err);

      final retry = req.copyWith(
        headers: {...req.headers, _authHeader: '$_bearer$fresh'},
        extra: {...req.extra, _retriedKey: true},
      );
      return handler.resolve(await dio.fetch<dynamic>(retry));
    } on DioException catch (e) {
      return handler.next(e);
    } catch (_) {
      return handler.next(err);
    }
  }
}
