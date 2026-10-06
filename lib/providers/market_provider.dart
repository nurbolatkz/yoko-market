import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../models/cart_item.dart';
import '../models/user_profile.dart';

class MarketProvider with ChangeNotifier {
  // User Profile
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

  // Products Catalog (Dummy Data)
  final List<Product> _products = [
    Product(
      id: 'p1',
      title: 'Подгузники YokoSun XL 12–17 кг',
      description: 'Мягкие дышащие подгузники с надежной защитой до 12 часов.',
      price: 5990,
      imageUrl:
          'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=600',
      category: 'Подгузники',
      packageInfo: 'XL · 12–17 кг · 64 шт',
      rating: 4.8,
    ),
    Product(
      id: 'p2',
      title: 'Подгузники Futari L 9–14 кг',
      description: 'Комфортная посадка и нежный внутренний слой для чувствительной кожи.',
      price: 5490,
      imageUrl:
          'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=600',
      category: 'Подгузники',
      packageInfo: 'L · 9–14 кг · 54 шт',
      rating: 4.6,
    ),
    Product(
      id: 'p3',
      title: 'Подгузники YokoSun Premium S',
      description: 'Премиальная серия для новорожденных весом от 4 до 8 кг.',
      price: 4990,
      imageUrl:
          'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=600',
      category: 'Подгузники',
      packageInfo: 'S · 4–8 кг · 70 шт',
      rating: 4.9,
    ),
    Product(
      id: 'p4',
      title: 'Влажные салфетки Aura, 120 шт',
      description: 'Детские гипоаллергенные салфетки без спирта и парабенов.',
      price: 1290,
      imageUrl:
          'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=600',
      category: 'Салфетки',
      packageInfo: '120 шт в упаковке',
      rating: 4.3,
    ),
    Product(
      id: 'p5',
      title: 'Детский шампунь Comfy, 300 мл',
      description: 'Бережная формула без слез для ежедневного ухода.',
      price: 1890,
      imageUrl:
          'https://images.unsplash.com/photo-1556905055-8f358a7a47b2?w=600',
      category: 'Детская косметика',
      packageInfo: '300 мл',
      rating: 4.7,
    ),
    Product(
      id: 'p6',
      title: 'Гель для стирки детского белья',
      description: 'Эффективно удаляет пятна и полностью выполаскивается.',
      price: 3290,
      imageUrl:
          'https://images.unsplash.com/photo-1587829741301-dc798b83add3?w=600',
      category: 'Бытовая химия',
      packageInfo: '1,5 л',
      rating: 4.8,
    ),
    Product(
      id: 'p7',
      title: 'Крем под подгузник YokoSun',
      description: 'Успокаивает и защищает нежную кожу малыша.',
      price: 1690,
      imageUrl:
          'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600',
      category: 'Детская косметика',
      packageInfo: '75 мл',
      rating: 4.4,
    ),
    Product(
      id: 'p8',
      title: 'Одноразовые пеленки 60×90',
      description: 'Мягкие впитывающие пеленки, 30 штук в упаковке.',
      price: 3790,
      imageUrl:
          'https://images.unsplash.com/photo-1572635196237-14b3f281503f?w=600',
      category: 'Другое',
      packageInfo: '60 × 90 см · 30 шт',
      rating: 4.5,
    ),
  ];

  List<Product> get products => _products;

  // Categories
  List<String> get categories {
    final set = {'All', ..._products.map((p) => p.category)};
    return set.toList();
  }

  String _selectedCategory = 'All';
  String get selectedCategory => _selectedCategory;

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  // Search
  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void resetCatalogFilters() {
    _searchQuery = '';
    _selectedCategory = 'All';
    notifyListeners();
  }

  List<Product> get filteredProducts {
    return _products.where((product) {
      final matchesCategory =
          _selectedCategory == 'All' || product.category == _selectedCategory;
      final matchesSearch =
          product.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product.description.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
      return matchesCategory && matchesSearch;
    }).toList();
  }

  // Cart
  final Map<String, CartItem> _cartItems = {};

  List<CartItem> get cartItems => _cartItems.values.toList();

  int get cartItemCount {
    return _cartItems.values.fold(0, (sum, item) => sum + item.quantity);
  }

  double get cartTotalAmount {
    return _cartItems.values.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  void addToCart(Product product) {
    if (_cartItems.containsKey(product.id)) {
      _cartItems[product.id]!.quantity += 1;
    } else {
      _cartItems[product.id] = CartItem(product: product);
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

  // Wishlist
  final Set<String> _wishlistIds = {'p1', 'p3'};

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

  List<Product> get favoriteProducts {
    return _products.where((p) => _wishlistIds.contains(p.id)).toList();
  }
}
