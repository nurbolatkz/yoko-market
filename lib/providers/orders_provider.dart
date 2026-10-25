import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/order.dart';
import '../providers/auth_provider.dart';
import '../services/orders_api.dart';
import '../utils/dio_error.dart';

class OrdersProvider with ChangeNotifier {
  OrdersProvider({OrdersApi? api}) : _api = api ?? OrdersApi();

  final OrdersApi _api;
  List<OrderSummary> _orders = const [];
  bool _loading = false;
  String? _error;

  List<OrderSummary> get orders => List.unmodifiable(_orders);
  bool get loading => _loading;
  String? get error => _error;

  Future<void> fetchOrders(AuthProvider auth) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      String? token = await auth.getAccessToken();

      if (token == null) {
        final fresh = await auth.ensureFreshToken();
        if (fresh == null) {
          _error = 'auth';
          return;
        }
        token = fresh;
      }

      try {
        _orders = await _api.getOrders(token: token);
      } on DioException catch (e) {
        if ((e.response?.statusCode ?? 0) == 401) {
          final fresh = await auth.ensureFreshToken();
          if (fresh == null) {
            _error = 'auth';
            return;
          }
          _orders = await _api.getOrders(token: fresh);
        } else {
          rethrow;
        }
      }
      _error = null;
    } catch (e) {
      _error = networkErrorMessage(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clearOrders() {
    _orders = const [];
    _error = null;
    _loading = false;
    notifyListeners();
  }
}
