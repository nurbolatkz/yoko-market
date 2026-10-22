import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/cart_item.dart';
import '../models/checkout_estimate.dart';

class CheckoutApi {
  CheckoutApi({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              responseType: ResponseType.json,
            ));

  final Dio _dio;

  /// GET /checkout/cities — public; returns serviced cities for city picker.
  Future<List<BranchCity>> getCities() async {
    final resp = await _dio.get<dynamic>('/checkout/cities');
    return (resp.data as List<dynamic>)
        .map((e) => BranchCity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // POST /checkout — creates the order.
  // Throws [PendingOrderException] on 409 (active pending order exists).
  // Throws [PriceChangedException] on 422 price_changed (server total differs from confirmed).
  // Throws [DioException] for 400 (stock/product errors), 401, network errors.
  Future<PlaceOrderResult> placeOrder({
    required String token,
    required List<CartItem> items,
    String? address,
    String? idempotencyKey,
    int? confirmedTotal,
    int bonusUsed = 0,
  }) async {
    final body = <String, dynamic>{
      'items': items
          .map((e) => {
                'product_id': e.product.id,
                'name': e.product.title,
                'qty': e.quantity,
                'price': e.product.price.round(),
              })
          .toList(),
      if (address != null && address.isNotEmpty) 'address': address,
      // ignore: use_null_aware_elements
      if (confirmedTotal != null) 'confirmed_total': confirmedTotal,
      if (bonusUsed > 0) 'bonus_used': bonusUsed,
    };

    final headers = <String, dynamic>{'Authorization': 'Bearer $token'};
    if (idempotencyKey != null) headers['Idempotency-Key'] = idempotencyKey;

    try {
      final resp = await _dio.post<dynamic>(
        '/checkout',
        data: body,
        options: Options(headers: headers),
      );
      return PlaceOrderResult.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        final detail = (e.response?.data as Map<String, dynamic>?)?['detail'];
        if (detail is Map<String, dynamic> &&
            detail['code'] == 'pending_order_exists') {
          throw PendingOrderException(
            orderNumber: detail['order_number'] as String? ?? '',
            total: (detail['total'] as num?)?.toInt() ?? 0,
          );
        }
      }
      if (e.response?.statusCode == 422) {
        final detail = (e.response?.data as Map<String, dynamic>?)?['detail'];
        if (detail is Map<String, dynamic> &&
            detail['code'] == 'price_changed') {
          throw PriceChangedException(
            newEstimate: CheckoutEstimate.fromJson(detail),
            confirmedTotal: (detail['confirmed_total'] as num?)?.toInt() ?? 0,
          );
        }
      }
      rethrow;
    }
  }

  Future<CheckoutEstimate> estimate({
    required String token,
    required List<CartItem> items,
    String? address,
    int bonusUsed = 0,
  }) async {
    final body = <String, dynamic>{
      'items': items
          .map((e) => {
                'product_id': e.product.id,
                'name': e.product.title,
                'qty': e.quantity,
                'price': e.product.price.round(),
              })
          .toList(),
      if (address != null && address.isNotEmpty) 'address': address,
      if (bonusUsed > 0) 'bonus_used': bonusUsed,
    };

    final resp = await _dio.post<dynamic>(
      '/checkout/estimate',
      data: body,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    return CheckoutEstimate.fromJson(resp.data as Map<String, dynamic>);
  }
}
