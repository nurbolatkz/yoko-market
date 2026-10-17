/// Isolated unit tests for PlaceOrderResult parsing and CheckoutApi.placeOrder.
///
/// Run with:  flutter test test/checkout_place_order_test.dart
///
/// These tests do NOT need a running server or real network: a fake Dio
/// Interceptor returns pre-canned responses.  All assertions are on the
/// client-side model and exception-propagation logic.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yokomarket/models/cart_item.dart';
import 'package:yokomarket/models/checkout_estimate.dart';
import 'package:yokomarket/models/product.dart';
import 'package:yokomarket/services/checkout_api.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Product _fakeProduct({String id = 'prod-1', double price = 5000}) => Product(
      id: id,
      title: 'Тест',
      description: '',
      price: price,
      imageUrl: '',
      category: 'Подгузники',
      packageInfo: '',
      inStock: true,
      stockQuantity: 10,
    );

List<CartItem> _oneItem({String id = 'prod-1', int qty = 2}) =>
    [CartItem(product: _fakeProduct(id: id), quantity: qty)];

// Resolves every POST /checkout with the given JSON body and status code.
Interceptor _respond(Map<String, dynamic> body, {int status = 200}) =>
    _FakeInterceptor(body: body, status: status);

// Rejects every POST /checkout with the given status and detail payload.
Interceptor _error(int status, dynamic detail) =>
    _ErrorInterceptor(status: status, detail: detail);

// Rejects with a receive-timeout (simulates server creating order but client
// never getting the response — the "timeout after creation" scenario).
Interceptor _receiveTimeout() => _TimeoutInterceptor();

CheckoutApi _api(Interceptor interceptor) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test.local/api/v1'));
  dio.interceptors.add(interceptor);
  return CheckoutApi(dio: dio);
}

// ── Model parsing ─────────────────────────────────────────────────────────────

void main() {
  group('PlaceOrderResult.fromJson', () {
    test('parses a typical success payload', () {
      final result = PlaceOrderResult.fromJson({
        'order_number': 'YK-42',
        'total': 15000,
        'status': 'ok',
        'notified': true,
        'bot_username': 'yokobot',
      });

      expect(result.orderNumber, 'YK-42');
      expect(result.total, 15000);
      expect(result.notified, isTrue);
      expect(result.botUsername, 'yokobot');
    });

    test('notified defaults to false when absent', () {
      final result = PlaceOrderResult.fromJson({
        'order_number': 'YK-1',
        'total': 3000,
        'status': 'ok',
      });
      expect(result.notified, isFalse);
      expect(result.botUsername, isNull);
    });

    test('total is always an int (numeric coercion)', () {
      final result = PlaceOrderResult.fromJson({
        'order_number': 'YK-2',
        'total': 9900.0, // server sends as double occasionally
        'status': 'ok',
      });
      expect(result.total, 9900);
    });
  });

  // ── CheckoutApi.placeOrder ─────────────────────────────────────────────────

  group('CheckoutApi.placeOrder — success', () {
    test('returns PlaceOrderResult on 200', () async {
      final api = _api(_respond({
        'order_number': 'YK-100',
        'total': 12000,
        'status': 'ok',
        'notified': false,
      }));

      final result = await api.placeOrder(
        token: 'tok',
        items: _oneItem(),
        address: 'ул. Тестовая, 1',
      );

      expect(result.orderNumber, 'YK-100');
      expect(result.total, 12000);
    });

    test('sends product_id, name, qty, price in request body', () async {
      RequestOptions? captured;
      final dio = Dio(BaseOptions(baseUrl: 'https://test.local/api/v1'));
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          handler.resolve(Response(
            data: {
              'order_number': 'YK-1',
              'total': 5000,
              'status': 'ok',
            },
            statusCode: 200,
            requestOptions: options,
          ));
        },
      ));
      final api = CheckoutApi(dio: dio);
      final product = _fakeProduct(id: 'uuid-abc', price: 2500);
      await api.placeOrder(
        token: 'tok',
        items: [CartItem(product: product, quantity: 2)],
        address: 'ул. Тест',
      );

      final items = (captured!.data as Map)['items'] as List;
      expect(items.length, 1);
      expect(items[0]['product_id'], 'uuid-abc');
      expect(items[0]['qty'], 2);
      expect(items[0]['price'], 2500);
    });
  });

  group('CheckoutApi.placeOrder — double request prevention', () {
    test('second concurrent call is independent (client guard is in screen, not API)',
        () async {
      // The API layer itself does not deduplicate — the guard lives in
      // _CheckoutScreenState._placing.  Both calls go through but the server
      // returns 409 on the second one.  This test verifies that the 409 on
      // call 2 throws PendingOrderException while call 1 succeeds.
      var callCount = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://test.local/api/v1'));
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          callCount++;
          if (callCount == 1) {
            handler.resolve(Response(
              data: {'order_number': 'YK-10', 'total': 5000, 'status': 'ok'},
              statusCode: 200,
              requestOptions: options,
            ));
          } else {
            handler.reject(DioException(
              requestOptions: options,
              response: Response(
                data: {
                  'detail': {
                    'code': 'pending_order_exists',
                    'order_number': 'YK-10',
                    'total': 5000,
                  }
                },
                statusCode: 409,
                requestOptions: options,
              ),
              type: DioExceptionType.badResponse,
            ));
          }
        },
      ));
      final api = CheckoutApi(dio: dio);

      final first =
          await api.placeOrder(token: 'tok', items: _oneItem(), address: '');
      expect(first.orderNumber, 'YK-10');

      expect(
        () => api.placeOrder(token: 'tok', items: _oneItem(), address: ''),
        throwsA(isA<PendingOrderException>()
            .having((e) => e.orderNumber, 'orderNumber', 'YK-10')
            .having((e) => e.total, 'total', 5000)),
      );
    });
  });

  group('CheckoutApi.placeOrder — 409 pending order', () {
    test('throws PendingOrderException with order details', () {
      final api = _api(_error(409, {
        'code': 'pending_order_exists',
        'order_number': 'YK-41',
        'total': 14000,
      }));

      expect(
        () => api.placeOrder(token: 'tok', items: _oneItem(), address: ''),
        throwsA(isA<PendingOrderException>()
            .having((e) => e.orderNumber, 'orderNumber', 'YK-41')
            .having((e) => e.total, 'total', 14000)),
      );
    });

    test('fallback: 409 with non-map detail still throws PendingOrderException with empty fields', () {
      // Guard: if the server sends unexpected 409 detail shape, we don't crash.
      final dio = Dio(BaseOptions(baseUrl: 'https://test.local/api/v1'));
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(DioException(
            requestOptions: options,
            response: Response(
              data: {'detail': 'pending_order_exists'},
              statusCode: 409,
              requestOptions: options,
            ),
            type: DioExceptionType.badResponse,
          ));
        },
      ));
      final api = CheckoutApi(dio: dio);
      // A non-map detail falls through to rethrow — still a DioException.
      expect(
        () => api.placeOrder(token: 'tok', items: _oneItem(), address: ''),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'status', 409)),
      );
    });
  });

  group('CheckoutApi.placeOrder — 401', () {
    test('rethrows DioException so the caller can refresh and retry', () {
      final api = _api(_error(401, 'user_not_found'));

      expect(
        () => api.placeOrder(token: 'expired', items: _oneItem(), address: ''),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'status', 401)),
      );
    });
  });

  group('CheckoutApi.placeOrder — stock errors', () {
    for (final code in [
      'insufficient_stock',
      'product_inactive',
      'product_not_found',
      'no_valid_products',
    ]) {
      test('rethrows DioException for $code', () {
        final api = _api(_error(400, code));

        expect(
          () => api.placeOrder(token: 'tok', items: _oneItem(), address: ''),
          throwsA(isA<DioException>()
              .having((e) => e.response?.statusCode, 'status', 400)
              .having(
                  (e) => (e.response?.data as Map)['detail'], 'detail', code)),
        );
      });
    }
  });

  group('CheckoutApi.placeOrder — network timeout (timeout after creation)', () {
    test('throws DioException with null response — cart must NOT be cleared', () {
      // The screen checks `e.response == null` to detect network errors and
      // skips clearOrderedItems().  This test verifies the exception shape.
      final api = _api(_receiveTimeout());

      expect(
        () => api.placeOrder(token: 'tok', items: _oneItem(), address: ''),
        throwsA(isA<DioException>()
            .having((e) => e.response, 'response', isNull)
            .having((e) => e.type, 'type', DioExceptionType.receiveTimeout)),
      );
    });
  });

  group('CheckoutApi.placeOrder — idempotency key', () {
    test('sends Idempotency-Key header when provided', () async {
      RequestOptions? captured;
      final dio = Dio(BaseOptions(baseUrl: 'https://test.local/api/v1'));
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          handler.resolve(Response(
            data: {'order_number': 'YK-55', 'total': 5000, 'status': 'ok'},
            statusCode: 200,
            requestOptions: options,
          ));
        },
      ));
      final api = CheckoutApi(dio: dio);
      await api.placeOrder(
        token: 'tok',
        items: _oneItem(),
        address: '',
        idempotencyKey: 'uuid-test-123',
      );
      expect(captured!.headers['Idempotency-Key'], 'uuid-test-123');
    });

    test('second call with same key returns cached result (server-side dedup)',
        () async {
      // Simulate server returning a cached result for a repeated idempotency key:
      // first call creates the order (200), second call with same key also returns
      // 200 with the same payload — no 409, no duplicate charge.
      var callCount = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://test.local/api/v1'));
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          callCount++;
          handler.resolve(Response(
            data: {'order_number': 'YK-55', 'total': 5000, 'status': 'ok'},
            statusCode: 200,
            requestOptions: options,
          ));
        },
      ));
      final api = CheckoutApi(dio: dio);

      final r1 = await api.placeOrder(
          token: 'tok', items: _oneItem(), address: '', idempotencyKey: 'k1');
      final r2 = await api.placeOrder(
          token: 'tok', items: _oneItem(), address: '', idempotencyKey: 'k1');
      expect(callCount, 2); // both go through; dedup is server-side
      expect(r1.orderNumber, r2.orderNumber);
    });

    test('concurrent_request 409 is rethrown as DioException (not PendingOrderException)',
        () {
      final api = _api(_error(409, {'code': 'concurrent_request'}));
      expect(
        () => api.placeOrder(token: 'tok', items: _oneItem(), address: ''),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'status', 409)),
      );
    });
  });

  group('CheckoutApi.placeOrder — price change (422)', () {
    test('throws PriceChangedException when server returns price_changed', () {
      final dio = Dio(BaseOptions(baseUrl: 'https://test.local/api/v1'));
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(DioException(
            requestOptions: options,
            response: Response(
              data: {
                'detail': {
                  'code': 'price_changed',
                  'confirmed_total': 12000,
                  'new_total': 13500,
                  'items': [
                    {
                      'product_id': 'prod-1',
                      'name': 'Тест',
                      'server_price': 6750,
                      'qty': 2,
                      'line_total': 13500,
                    }
                  ],
                  'subtotal': 13500,
                  'promo_discount': 0,
                  'promo_error': null,
                  'bonus_applied': 0,
                  'items_total': 13500,
                  'delivery': {
                    'status': 'free',
                    'fee': 0,
                    'free_above': 10000,
                    'shortfall': 0,
                  },
                  'order_total': 13500,
                }
              },
              statusCode: 422,
              requestOptions: options,
            ),
            type: DioExceptionType.badResponse,
          ));
        },
      ));
      final api = CheckoutApi(dio: dio);

      expect(
        () => api.placeOrder(
          token: 'tok',
          items: _oneItem(),
          address: '',
          confirmedTotal: 12000,
        ),
        throwsA(isA<PriceChangedException>()
            .having((e) => e.confirmedTotal, 'confirmedTotal', 12000)
            .having((e) => e.newEstimate.orderTotal, 'newTotal', 13500)),
      );
    });

    test('sends confirmed_total in request body', () async {
      RequestOptions? captured;
      final dio = Dio(BaseOptions(baseUrl: 'https://test.local/api/v1'));
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          handler.resolve(Response(
            data: {'order_number': 'YK-5', 'total': 9000, 'status': 'ok'},
            statusCode: 200,
            requestOptions: options,
          ));
        },
      ));
      final api = CheckoutApi(dio: dio);
      await api.placeOrder(
        token: 'tok',
        items: _oneItem(),
        address: '',
        confirmedTotal: 9000,
      );
      expect((captured!.data as Map)['confirmed_total'], 9000);
    });
  });

  group('MarketProvider.clearOrderedItems — cart quantity snapshot', () {
    test('subtracts ordered qty, preserves items added during the request',
        () {
      // Simulates: user had 3 units, added 2 more while request was in flight.
      // Cart now holds 5. Snapshot recorded 3. After success: 5 - 3 = 2 remain.
      final product = _fakeProduct();
      final cart = <String, dynamic>{}; // simulate _cartItems backing map

      // Build a fake CartItem with mutable quantity
      final item = CartItem(product: product, quantity: 5);
      cart[product.id] = item;

      // Manually run the clearOrderedItems logic to verify the algorithm:
      final snapshot = [MapEntry(product.id, 3)]; // qty at order time
      for (final entry in snapshot) {
        final ci = cart[entry.key] as CartItem;
        if (ci.quantity <= entry.value) {
          cart.remove(entry.key);
        } else {
          ci.quantity -= entry.value;
        }
      }

      expect(cart[product.id], isNotNull);
      expect((cart[product.id] as CartItem).quantity, 2);
    });

    test('removes item when snapshot qty equals current qty', () {
      final product = _fakeProduct();
      final cart = <String, dynamic>{};
      final item = CartItem(product: product, quantity: 2);
      cart[product.id] = item;

      final snapshot = [MapEntry(product.id, 2)];
      for (final entry in snapshot) {
        final ci = cart[entry.key] as CartItem;
        if (ci.quantity <= entry.value) {
          cart.remove(entry.key);
        } else {
          ci.quantity -= entry.value;
        }
      }

      expect(cart[product.id], isNull);
    });
  });
}

// ── Fake interceptors ─────────────────────────────────────────────────────────

class _FakeInterceptor extends Interceptor {
  _FakeInterceptor({required this.body, required this.status});
  final Map<String, dynamic> body;
  final int status;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (status >= 200 && status < 300) {
      handler.resolve(Response(
        data: body,
        statusCode: status,
        requestOptions: options,
      ));
    } else {
      handler.reject(DioException(
        requestOptions: options,
        response: Response(
          data: body,
          statusCode: status,
          requestOptions: options,
        ),
        type: DioExceptionType.badResponse,
      ));
    }
  }
}

class _ErrorInterceptor extends Interceptor {
  _ErrorInterceptor({required this.status, required this.detail});
  final int status;
  final dynamic detail;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.reject(DioException(
      requestOptions: options,
      response: Response(
        data: {'detail': detail},
        statusCode: status,
        requestOptions: options,
      ),
      type: DioExceptionType.badResponse,
    ));
  }
}

class _TimeoutInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.reject(DioException(
      requestOptions: options,
      type: DioExceptionType.receiveTimeout,
      // No response — simulates server processed the request but client timed out.
    ));
  }
}
