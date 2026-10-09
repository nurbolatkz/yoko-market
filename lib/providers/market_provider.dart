import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/product_category.dart';
import '../services/catalog_api.dart';

class MarketProvider with ChangeNotifier {
  MarketProvider({CatalogDataSource? catalogDataSource})
    : _catalogDataSource = catalogDataSource ?? CatalogApi() {
    _loadCart();
  }

  final CatalogDataSource _catalogDataSource;

  static const int _pageSize = 50;
  static const String _cartKey = 'cart_v1';

  List<Product> _products = const [];
  List<ProductCategory> _catalogCategories = const [];
  bool _catalogLoading = false;
  String? _catalogError;
  int _requestVersion = 0;

  int _loadedOffset = 0;
  bool _hasMore = false;
  bool _isLoadingMore = false;

  List<Product> get products => List.unmodifiable(_products);
  bool get catalogLoading => _catalogLoading;
  String? get catalogError => _catalogError;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  List<String> get categories => [
    'All',
    ..._catalogCategories.map((category) => category.name).toSet(),
  ];

  String _selectedCategory = 'All';
  String get selectedCategory => _selectedCategory;

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<Product> get filteredProducts => _products;

  Future<void> loadCatalog() async {
    final requestVersion = ++_requestVersion;
    _catalogLoading = true;
    _catalogError = null;
    _loadedOffset = 0;
    _hasMore = false;
    notifyListeners();

    try {
      final results = await Future.wait<dynamic>([
        _catalogDataSource.getCategories(),
        _catalogDataSource.getProducts(
          category: _apiCategory,
          search: _searchQuery,
          limit: _pageSize,
          offset: 0,
        ),
      ]);
      if (requestVersion != _requestVersion) return;
      _catalogCategories = results[0] as List<ProductCategory>;
      final page = results[1] as List<Product>;
      _products = page;
      _loadedOffset = page.length;
      _hasMore = page.length == _pageSize;
    } catch (_) {
      if (requestVersion != _requestVersion) return;
      _products = const [];
      _catalogError = 'Не удалось загрузить товары. Проверьте подключение.';
      _hasMore = false;
    } finally {
      if (requestVersion == _requestVersion) {
        _catalogLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadProducts() async {
    final requestVersion = ++_requestVersion;
    _catalogLoading = true;
    _catalogError = null;
    _loadedOffset = 0;
    _hasMore = false;
    notifyListeners();

    try {
      final page = await _catalogDataSource.getProducts(
        category: _apiCategory,
        search: _searchQuery,
        limit: _pageSize,
        offset: 0,
      );
      if (requestVersion != _requestVersion) return;
      _products = page;
      _loadedOffset = page.length;
      _hasMore = page.length == _pageSize;
    } catch (_) {
      if (requestVersion != _requestVersion) return;
      _products = const [];
      _catalogError = 'Не удалось загрузить товары. Проверьте подключение.';
      _hasMore = false;
    } finally {
      if (requestVersion == _requestVersion) {
        _catalogLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMoreProducts() async {
    if (_isLoadingMore || !_hasMore || _catalogLoading) return;
    _isLoadingMore = true;
    final requestVersion = _requestVersion;
    notifyListeners();

    try {
      final more = await _catalogDataSource.getProducts(
        category: _apiCategory,
        search: _searchQuery,
        limit: _pageSize,
        offset: _loadedOffset,
      );
      if (_requestVersion != requestVersion) return;
      // Deduplicate: discard any product_id already present in the current list.
      final existingIds = {for (final p in _products) p.id};
      final fresh = more.where((p) => !existingIds.contains(p.id)).toList();
      _products = [..._products, ...fresh];
      _loadedOffset += more.length;
      _hasMore = more.length == _pageSize;
    } catch (_) {
      // Existing products remain visible; user can scroll up and retry.
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  String? get _apiCategory =>
      _selectedCategory == 'All' ? null : _selectedCategory;

  Future<void> resetCatalogFilters() async {
    _searchQuery = '';
    _selectedCategory = 'All';
    await loadProducts();
  }

  // ── Cart ──────────────────────────────────────────────────────────────────

  final Map<String, CartItem> _cartItems = {};

  List<CartItem> get cartItems => _cartItems.values.toList();

  int get cartItemCount =>
      _cartItems.values.fold(0, (sum, item) => sum + item.quantity);

  double get cartTotalAmount =>
      _cartItems.values.fold(0.0, (sum, item) => sum + item.totalPrice);

  /// Returns how many units of [product] the cart already holds.
  int cartQuantityFor(String productId) =>
      _cartItems[productId]?.quantity ?? 0;

  void addToCart(Product product) {
    if (!product.inStock) return;
    final current = cartQuantityFor(product.id);
    if (current >= product.stockQuantity) return;
    if (_cartItems.containsKey(product.id)) {
      _cartItems[product.id]!.quantity += 1;
    } else {
      _cartItems[product.id] = CartItem(product: product);
    }
    notifyListeners();
    _saveCart();
  }

  void addToCartWithQty(Product product, int qty) {
    if (!product.inStock || qty <= 0) return;
    final current = cartQuantityFor(product.id);
    final allowed = (product.stockQuantity - current).clamp(0, qty);
    if (allowed <= 0) return;
    if (_cartItems.containsKey(product.id)) {
      _cartItems[product.id]!.quantity += allowed;
    } else {
      _cartItems[product.id] = CartItem(product: product, quantity: allowed);
    }
    notifyListeners();
    _saveCart();
  }

  void removeFromCart(String productId) {
    _cartItems.remove(productId);
    notifyListeners();
    _saveCart();
  }

  void updateQuantity(String productId, int quantity) {
    if (!_cartItems.containsKey(productId)) return;
    final item = _cartItems[productId]!;
    if (quantity <= 0) {
      _cartItems.remove(productId);
    } else {
      item.quantity = quantity.clamp(1, item.product.stockQuantity);
    }
    notifyListeners();
    _saveCart();
  }

  void clearCart() {
    _cartItems.clear();
    notifyListeners();
    _saveCart();
  }

  Future<void> _loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cartKey);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List<dynamic>;
      final loaded = <String, CartItem>{};
      for (final entry in list) {
        final item = CartItem.fromJson(entry as Map<String, dynamic>);
        if (item.product.id.isNotEmpty) {
          loaded[item.product.id] = item;
        }
      }
      if (loaded.isNotEmpty) {
        _cartItems.addAll(loaded);
        notifyListeners();
      }
    } catch (_) {
      // SharedPreferences unavailable (test env) or data corrupted — start fresh
    }
  }

  void _saveCart() {
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setString(
          _cartKey,
          jsonEncode(_cartItems.values.map((i) => i.toJson()).toList()),
        ))
        .catchError((_) {});
  }

  // ── Favourites ────────────────────────────────────────────────────────────

  final Set<String> _wishlistIds = {};

  Set<String> get wishlistIds => _wishlistIds;
  bool isFavorite(String productId) => _wishlistIds.contains(productId);

  void toggleFavorite(String productId) {
    if (_wishlistIds.contains(productId)) {
      _wishlistIds.remove(productId);
    } else {
      _wishlistIds.add(productId);
    }
    notifyListeners();
  }

  List<Product> get favoriteProducts =>
      _products.where((product) => _wishlistIds.contains(product.id)).toList();
}
