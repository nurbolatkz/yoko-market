import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/order.dart';

class OrdersApi {
  OrdersApi({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              responseType: ResponseType.json,
            ));

  final Dio _dio;

  Future<List<OrderSummary>> getOrders({required String token}) async {
    final resp = await _dio.get<dynamic>(
      '/my-orders',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final list = resp.data as List<dynamic>;
    return list
        .map((e) => OrderSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<OrderSummary> getOrder({
    required String id,
    required String token,
  }) async {
    final resp = await _dio.get<dynamic>(
      '/my-orders/$id',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return OrderSummary.fromJson(resp.data as Map<String, dynamic>);
  }
}
