import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/user_address.dart';

class AddressApi {
  AddressApi({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              responseType: ResponseType.json,
            ));

  final Dio _dio;

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  Future<List<UserAddress>> list(String token) async {
    final resp = await _dio.get<dynamic>('/mobile/addresses', options: _auth(token));
    return (resp.data as List<dynamic>)
        .map((e) => UserAddress.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<UserAddress> create(String token, UserAddress addr) async {
    final resp = await _dio.post<dynamic>(
      '/mobile/addresses',
      data: addr.toJson(),
      options: _auth(token),
    );
    return UserAddress.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<UserAddress> update(String token, String id, UserAddress addr) async {
    final resp = await _dio.patch<dynamic>(
      '/mobile/addresses/$id',
      data: addr.toJson(),
      options: _auth(token),
    );
    return UserAddress.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> delete(String token, String id) async {
    await _dio.delete<dynamic>('/mobile/addresses/$id', options: _auth(token));
  }

  Future<UserAddress> setDefault(String token, String id) async {
    final resp = await _dio.post<dynamic>(
      '/mobile/addresses/$id/set-default',
      options: _auth(token),
    );
    return UserAddress.fromJson(resp.data as Map<String, dynamic>);
  }
}
