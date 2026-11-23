import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';
import '../services/wishlist_api.dart';

class WishlistProvider with ChangeNotifier {
  WishlistProvider() {
    _loadLocal();
  }

  static const _localKey = 'wishlist_v1';

  final _api = WishlistApi();

  // product_id → Product snapshot
  final Map<String, Product> _items = {};
  bool _loading = false;
  String? _error;

  List<Product> get products => _items.values.toList();
  Set<String> get ids => _items.keys.toSet();
  bool get loading => _loading;
  String? get error => _error;
  bool isFavorite(String id) => _items.containsKey(id);
  int get count => _items.length;

  // ── Local persistence ──────────────────────────────────────────────────────

  Future<void> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localKey);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List<dynamic>;
      for (final e in list) {
        final p = Product.fromCartJson(e as Map<String, dynamic>);
        if (p.id.isNotEmpty) _items[p.id] = p;
      }
      notifyListeners();
    } catch (_) {}
  }

  void _saveLocal() {
    SharedPreferences.getInstance()
        .then((p) => p.setString(
              _localKey,
              jsonEncode(_items.values.map((p) => p.toJson()).toList()),
            ))
        .catchError((_) => false);
  }

  // ── Toggle (used from Home, Catalog, ProductDetail) ───────────────────────

  void toggle(Product product, {String? accessToken}) {
    if (_items.containsKey(product.id)) {
      _items.remove(product.id);
      if (accessToken != null) _backendRemove(product.id, accessToken);
    } else {
      _items[product.id] = product;
      if (accessToken != null) _backendAdd(product.id, accessToken);
    }
    notifyListeners();
    _saveLocal();
  }

  // ── Backend sync (called after login) ─────────────────────────────────────

  Future<void> syncAfterLogin(String accessToken) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      // Merge local items into the backend and get the full merged list back.
      final remoteIds = await _api.sync(accessToken, _items.keys.toList());

      // Keep local product snapshots for already-known IDs, mark others as
      // needing a fetch — for now we store a placeholder so the ID is tracked.
      for (final id in remoteIds) {
        if (!_items.containsKey(id)) {
          // No local snapshot; we have the ID — the favorites screen will show
          // the item once the catalog loads (via refreshFromCatalog).
          _items[id] = _placeholder(id);
        }
      }
      // Remove any IDs that the backend doesn't have (shouldn't happen but safe).
      _items.removeWhere((id, _) => !remoteIds.contains(id));
      _saveLocal();
    } on DioException {
      // Network failure: keep working with local list.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // Called after catalog loads so placeholder entries get real product data.
  void refreshFromCatalog(List<Product> catalogProducts) {
    var changed = false;
    for (final p in catalogProducts) {
      if (_items.containsKey(p.id) && _items[p.id]!.title.isEmpty) {
        _items[p.id] = p;
        changed = true;
      }
    }
    if (changed) {
      _saveLocal();
      notifyListeners();
    }
  }

  // ── On logout — clear everything for this user ────────────────────────────

  void clearForUser() {
    _items.clear();
    _error = null;
    SharedPreferences.getInstance()
        .then((p) => p.remove(_localKey))
        .catchError((_) => false);
    notifyListeners();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _backendAdd(String productId, String token) async {
    try {
      await _api.add(token, productId);
    } catch (_) {}
  }

  Future<void> _backendRemove(String productId, String token) async {
    try {
      await _api.remove(token, productId);
    } catch (_) {}
  }

  Product _placeholder(String id) => Product(
        id: id,
        title: '',
        description: '',
        price: 0,
        imageUrl: '',
        category: '',
        packageInfo: '',
        inStock: true,
        stockQuantity: 0,
      );
}
