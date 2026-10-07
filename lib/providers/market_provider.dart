import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/product_category.dart';
import '../models/user_profile.dart';
import '../services/catalog_api.dart';

class MarketProvider with ChangeNotifier {
  MarketProvider({CatalogDataSource? catalogDataSource})
    : _catalogDataSource = catalogDataSource ?? CatalogApi();

  final CatalogDataSource _catalogDataSource;

  static const int _pageSize = 50;

  UserProfile _user = UserProfile(
    name: 'Alex Johnson',
    email: 'alex.johnson@yokomarket.kz',
    phone: '+7 (777) 123-45-67',
    address: 'Abay Avenue 45, Almaty, Kazakhstan',
    avatarUrl:
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300',
  );

  UserProfile get user => _user;

  void updateUser(UserProfile updatedUser) {
    _user = updatedUser;
    notifyListeners();
  }

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
      _products = [..._products, ...more];
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

  final Map<String, CartItem> _cartItems = {};

  List<CartItem> get cartItems => _cartItems.values.toList();

  int get cartItemCount =>
      _cartItems.values.fold(0, (sum, item) => sum + item.quantity);

  double get cartTotalAmount =>
      _cartItems.values.fold(0.0, (sum, item) => sum + item.totalPrice);

  void addToCart(Product product) {
    if (!product.inStock) return;
    if (_cartItems.containsKey(product.id)) {
      _cartItems[product.id]!.quantity += 1;
    } else {
      _cartItems[product.id] = CartItem(product: product);
    }
    notifyListeners();
  }

  void addToCartWithQty(Product product, int qty) {
    if (!product.inStock || qty <= 0) return;
    if (_cartItems.containsKey(product.id)) {
      _cartItems[product.id]!.quantity += qty;
    } else {
      _cartItems[product.id] = CartItem(product: product, quantity: qty);
    }
    notifyListeners();
  }

  void removeFromCart(String productId) {
    _cartItems.remove(productId);
    notifyListeners();
  }

  void updateQuantity(String productId, int quantity) {
    if (_cartItems.containsKey(productId)) {
      if (quantity <= 0) {
        _cartItems.remove(productId);
      } else {
        _cartItems[productId]!.quantity = quantity;
      }
      notifyListeners();
    }
  }

  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }

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
