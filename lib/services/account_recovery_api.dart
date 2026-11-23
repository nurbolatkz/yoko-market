import 'package:dio/dio.dart';

import 'api_client.dart';

abstract class AccountRecoveryApi {
  Future<void> submitRequest({
    required String orderNumber,
    required String contact,
  });
}

class HttpAccountRecoveryApi implements AccountRecoveryApi {
  HttpAccountRecoveryApi({Dio? dio})
      : _dio = dio ?? ApiClient.create(timeout: const Duration(seconds: 10));

  final Dio _dio;

  @override
  Future<void> submitRequest({
    required String orderNumber,
    required String contact,
  }) async {
    await _dio.post<dynamic>(
      '/support/account-recovery',
      data: {'order_number': orderNumber, 'contact': contact},
    );
  }
}

class MockAccountRecoveryApi implements AccountRecoveryApi {
  @override
  Future<void> submitRequest({
    required String orderNumber,
    required String contact,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    // Simulate success silently
  }
}
