import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/market_provider.dart';
import '../theme/app_theme.dart';
import '../providers/wishlist_provider.dart';
import 'catalog_screen.dart';
import 'cart_screen.dart';
import 'favorites_screen.dart';
import 'product_catalog_screen.dart';
import 'profile_screen.dart';
import '../widgets/yo_bottom_nav.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final marketProvider = Provider.of<MarketProvider>(context);
    final cartCount = marketProvider.cartItemCount;
    final favCount = context.watch<WishlistProvider>().count;
    // Tab order from the client's YO market design:
    // Главная · Каталог · Избранное · Корзина · Профиль.
    const catalogTab = 1;
    const cartTab = 3;
    final screens = [
      CatalogScreen(
        onCategorySelected: (category) {
          marketProvider.setSelectedCategory(category);
          marketProvider.loadProducts();
          setState(() => _currentIndex = catalogTab);
        },
        onSearchSubmitted: () => setState(() => _currentIndex = catalogTab),
        onCartTapped: () => setState(() => _currentIndex = cartTab),
      ),
      const ProductCatalogScreen(),
      FavoritesScreen(
        onGoToCatalog: () => setState(() => _currentIndex = catalogTab),
      ),
      CartScreen(
        onGoToCatalog: () => setState(() => _currentIndex = catalogTab),
      ),
      const ProfileScreen(),
    ];

    // Not extendBody: every tab keeps its full height; the floating bar sits
    // on the warm page colour below the content.
    return Scaffold(
      backgroundColor: AppColors.peachBottom,
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: YoBottomNav(
        currentIndex: _currentIndex,
        onSelected: (index) => setState(() => _currentIndex = index),
        items: [
          const YoNavItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: 'Главная',
          ),
          const YoNavItem(
            icon: Icons.grid_view_outlined,
            selectedIcon: Icons.grid_view_rounded,
            label: 'Каталог',
          ),
          YoNavItem(
            icon: Icons.favorite_border_rounded,
            selectedIcon: Icons.favorite_rounded,
            label: 'Избранное',
            badgeCount: favCount,
          ),
          YoNavItem(
            icon: Icons.shopping_cart_outlined,
            selectedIcon: Icons.shopping_cart,
            label: 'Корзина',
            badgeCount: cartCount,
          ),
          const YoNavItem(
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}
