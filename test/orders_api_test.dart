/// Isolated unit tests for OrdersApi and OrderSummary model parsing.
///
/// Run with:  flutter test test/orders_api_test.dart
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yokomarket/models/order.dart';
import 'package:yokomarket/services/orders_api.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Map<String, dynamic> _orderJson({
  String id = 'order-uuid-1',
  String orderNumber = 'YK-42',
  String status = 'pending_payment',
  int totalAmount = 15000,
  String address = 'ул. Тестовая, 1',
  String createdAt = '2026-10-15T10:30:00+00:00',
  int promoDiscount = 0,
  int bonusUsed = 0,
}) =>
    {
      'id': id,
      'order_number': orderNumber,
      'status': status,
      'total_amount': totalAmount,
      'items': [
        {'name': 'Товар А', 'qty': 2, 'price': 5000},
        {'name': 'Товар Б', 'qty': 1, 'price': 5000},
      ],
      'address': address,
      'created_at': createdAt,
      'promo_code_used': null,
      'promo_discount': promoDiscount,
      'bonus_used': bonusUsed,
    };

OrdersApi _api(Interceptor interceptor) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test.local/api/v1'));
  dio.interceptors.add(interceptor);
  return OrdersApi(dio: dio);
}

// ── OrderSummary model parsing ────────────────────────────────────────────────

void main() {
  group('OrderSummary.fromJson', () {
    test('parses all fields correctly', () {
      final order = OrderSummary.fromJson(_orderJson(
        promoDiscount: 1500,
        bonusUsed: 500,
      ));
      expect(order.id, 'order-uuid-1');
      expect(order.orderNumber, 'YK-42');
      expect(order.status, 'pending_payment');
      expect(order.totalAmount, 15000);
      expect(order.items.length, 2);
      expect(order.address, 'ул. Тестовая, 1');
      expect(order.promoDiscount, 1500);
      expect(order.bonusUsed, 500);
    });

    test('statusLabel returns Russian text for all known statuses', () {
      final cases = {
        'pending_payment': 'Ожидает оплаты',
        'payment_received': 'Оплата получена',
        'confirmed': 'Подтверждён',
        'shipped': 'В доставке',
        'delivered': 'Доставлен',
        'cancelled': 'Отменён',
      };
      for (final entry in cases.entries) {
        final order =
            OrderSummary.fromJson(_orderJson(status: entry.key));
        expect(order.statusLabel, entry.value,
            reason: 'status: ${entry.key}');
      }
    });

    test('bonus_used defaults to 0 when absent', () {
      final json = Map<String, dynamic>.from(_orderJson());
      json.remove('bonus_used');
      final order = OrderSummary.fromJson(json);
      expect(order.bonusUsed, 0);
    });
  });

  group('OrderItem.fromJson', () {
    test('lineTotal = unitPrice × qty', () {
      final item = OrderItem.fromJson({'name': 'X', 'qty': 3, 'price': 4000});
      expect(item.lineTotal, 12000);
    });
  });

  // ── OrdersApi.getOrders ────────────────────────────────────────────────────

  group('OrdersApi.getOrders — success', () {
    test('returns list of OrderSummary on 200', () async {
      final api = _api(InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(Response(
          data: [_orderJson(), _orderJson(id: 'order-2', orderNumber: 'YK-43')],
          statusCode: 200,
          requestOptions: options,
        )),
      ));

      final orders = await api.getOrders(token: 'tok');
      expect(orders.length, 2);
      expect(orders[0].orderNumber, 'YK-42');
      expect(orders[1].orderNumber, 'YK-43');
    });

    test('sends Authorization header', () async {
      RequestOptions? captured;
      final api = _api(InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          handler.resolve(Response(
            data: <dynamic>[],
            statusCode: 200,
            requestOptions: options,
          ));
        },
      ));

      await api.getOrders(token: 'bearer-abc');
      expect(captured!.headers['Authorization'], 'Bearer bearer-abc');
    });

    test('returns empty list when server returns []', () async {
      final api = _api(InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(Response(
          data: <dynamic>[],
          statusCode: 200,
          requestOptions: options,
        )),
      ));

      final orders = await api.getOrders(token: 'tok');
      expect(orders, isEmpty);
    });
  });

  group('OrdersApi.getOrders — 401', () {
    test('rethrows DioException so caller can refresh and retry', () {
      final api = _api(InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(DioException(
          requestOptions: options,
          response: Response(
              data: {'detail': 'user_not_found'},
              statusCode: 401,
              requestOptions: options),
          type: DioExceptionType.badResponse,
        )),
      ));

      expect(
        () => api.getOrders(token: 'expired'),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'status', 401)),
      );
    });
  });

  // ── OrdersApi.getOrder (detail) ────────────────────────────────────────────

  group('OrdersApi.getOrder — detail endpoint', () {
    test('returns OrderSummary for valid id', () async {
      final api = _api(InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(Response(
          data: _orderJson(id: 'order-uuid-1'),
          statusCode: 200,
          requestOptions: options,
        )),
      ));

      final order = await api.getOrder(id: 'order-uuid-1', token: 'tok');
      expect(order.id, 'order-uuid-1');
    });

    test('hits /my-orders/{id} path', () async {
      RequestOptions? captured;
      final api = _api(InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          handler.resolve(Response(
            data: _orderJson(id: 'abc'),
            statusCode: 200,
            requestOptions: options,
          ));
        },
      ));

      await api.getOrder(id: 'abc', token: 'tok');
      expect(captured!.path, '/my-orders/abc');
    });

    test('throws DioException on 404 (foreign order)', () {
      final api = _api(InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(DioException(
          requestOptions: options,
          response: Response(
              data: {'detail': 'order_not_found'},
              statusCode: 404,
              requestOptions: options),
          type: DioExceptionType.badResponse,
        )),
      ));

      expect(
        () => api.getOrder(id: 'someone-elses-order', token: 'tok'),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'status', 404)),
      );
    });
  });
}
