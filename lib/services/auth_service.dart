import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import '../models/user_profile.dart';

class AuthService {
  AuthService({Dio? dio})
    : _dio = dio ?? Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          responseType: ResponseType.json,
        ),
      );

  final Dio _dio;
  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'yoko_access';
  static const _refreshKey = 'yoko_refresh';

  Future<int> requestOtp(String phone) async {
    final resp = await _dio.post<dynamic>(
      '/auth/request-otp',
      data: {'phone': phone},
    );
    final data = resp.data as Map<String, dynamic>;
    return (data['ttl'] as num?)?.toInt() ?? 300;
  }

  Future<UserProfile> verifyOtp(String phone, String code) async {
    final resp = await _dio.post<dynamic>(
      '/auth/verify-otp',
      data: {'phone': phone, 'code': code},
    );
    final data = resp.data as Map<String, dynamic>;
    await _saveTokens(
      data['access_token'] as String,
      data['refresh_token'] as String,
    );
    return UserProfile.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<String?> tryRefresh() async {
    final refreshToken = await _storage.read(key: _refreshKey);
    if (refreshToken == null) return null;
    try {
      final resp = await _dio.post<dynamic>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final data = resp.data as Map<String, dynamic>;
      final newAccess = data['access_token'] as String;
      final newRefresh = data['refresh_token'] as String;
      await _saveTokens(newAccess, newRefresh);
      return newAccess;
    } on DioException catch (e) {
      if ((e.response?.statusCode ?? 0) == 401) {
        await clearTokens();
      }
      return null;
    }
  }

  Future<UserProfile?> getProfile() async {
    final token = await _storage.read(key: _accessKey);
    if (token == null) return null;
    try {
      final resp = await _dio.get<dynamic>(
        '/profile',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return UserProfile.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if ((e.response?.statusCode ?? 0) == 401) return null;
      rethrow;
    }
  }

  Future<void> logout() async {
    final refreshToken = await _storage.read(key: _refreshKey);
    await clearTokens();
    if (refreshToken != null) {
      try {
        await _dio.post<dynamic>(
          '/auth/logout',
          data: {'refresh_token': refreshToken},
        );
      } catch (_) {}
    }
  }

  Future<bool> hasSession() async =>
      await _storage.read(key: _refreshKey) != null;

  Future<void> _saveTokens(String access, String refresh) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
