import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/market_provider.dart';
import '../providers/wishlist_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/product_image.dart';
import '../widgets/ui/empty_state.dart';
import 'auth/phone_screen.dart';
import 'product_detail_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key, this.onGoToCatalog});
  final VoidCallback? onGoToCatalog;

  @override
  Widget build(BuildContext context) {
    final wishlist = context.watch<WishlistProvider>();
    final auth = context.watch<AuthProvider>();
    final market = context.watch<MarketProvider>();

    // Resolve placeholder items against the live catalog.
    final products = wishlist.products
        .map((p) {
          if (p.title.isNotEmpty) return p;
          return market.products.where((cp) => cp.id == p.id).firstOrNull ?? p;
        })
        .where((p) => p.title.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Избранное'),
        actions: [
          if (products.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${products.length}',
                  style: const TextStyle(
                    color: AppColors.navyMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _Body(
        products: products,
        loading: wishlist.loading,
        isGuest: !auth.isAuthenticated,
        onGoToCatalog: onGoToCatalog,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.products,
    required this.loading,
    required this.isGuest,
    this.onGoToCatalog,
  });

  final List<Product> products;
  final bool loading;
  final bool isGuest;
  final VoidCallback? onGoToCatalog;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.purple),
      );
    }

    if (products.isEmpty) {
      return SingleChildScrollView(
        child: EmptyState(
          title: 'Избранное',
          icon: const Icon(
            Icons.favorite_border_rounded,
            size: 56,
            color: AppColors.purple,
          ),
          headline: 'Сохраните любимые товары',
          body: 'Нажмите на сердце в карточке товара, чтобы быстро найти его позже.',
          actionLabel: isGuest ? 'Войти' : 'Перейти в каталог',
          onAction: isGuest
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PhoneScreen()),
                  )
              : onGoToCatalog,
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.62,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) => _FavoriteCard(product: products[index]),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketProvider>();
    final wishlist = context.watch<WishlistProvider>();
    final auth = context.read<AuthProvider>();
    final cartQty = market.cartQuantityFor(product.id);
    final canAdd = product.inStock && cartQty < product.stockQuantity;
    final hasDiscount =
        product.originalPrice != null && product.originalPrice! > product.price;
    final discPct = hasDiscount
        ? ((1 - product.price / product.originalPrice!) * 100).round()
        : 0;

    return InkWell(
      borderRadius: AppRadii.cardBorder,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadii.cardBorder,
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo + discount badge + heart
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox.expand(
                      child: ProductImage(imageUrl: product.imageUrl),
                    ),
                  ),
                  if (hasDiscount)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.yellow,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '−$discPct%',
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () async {
                        final token = await auth.getAccessToken();
                        wishlist.toggle(product, accessToken: token);
                      },
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(230),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          size: 17,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Title
            Text(
              product.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 4),
            // Package info
            if (product.packageInfo.isNotEmpty)
              Text(
                product.packageInfo,
                style: const TextStyle(
                  color: AppColors.navyMuted,
                  fontSize: 10,
                ),
              ),
            const SizedBox(height: 4),
            // Price row
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasDiscount)
                        Text(
                          '${product.originalPrice!.toInt()} ₸',
                          style: const TextStyle(
                            color: AppColors.navyMuted,
                            fontSize: 10,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      Text(
                        '${product.price.toInt()} ₸',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.purple,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!product.inStock)
                  const _OutOfStockBadge()
                else if (cartQty == 0)
                  _AddButton(
                    onTap: canAdd ? () => market.addToCart(product) : null,
                  )
                else
                  _Stepper(
                    qty: cartQty,
                    onDecrement: () => market.updateQuantity(product.id, cartQty - 1),
                    onIncrement: canAdd
                        ? () => market.updateQuantity(product.id, cartQty + 1)
                        : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: onTap != null ? AppColors.purple : AppColors.border,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.add_rounded,
          color: onTap != null ? Colors.white : AppColors.navyMuted,
          size: 18,
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.qty,
    required this.onDecrement,
    this.onIncrement,
  });
  final int qty;
  final VoidCallback onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.purpleSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Btn(icon: Icons.remove_rounded, onTap: onDecrement),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '$qty',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.purple,
                fontSize: 13,
              ),
            ),
          ),
          _Btn(
            icon: Icons.add_rounded,
            onTap: onIncrement,
            disabled: onIncrement == null,
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.icon, this.onTap, this.disabled = false});
  final IconData icon;
  final VoidCallback? onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 28,
        height: 32,
        child: Icon(
          icon,
          size: 15,
          color: disabled ? AppColors.navyMuted : AppColors.purple,
        ),
      ),
    );
  }
}

class _OutOfStockBadge extends StatelessWidget {
  const _OutOfStockBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Нет в наличии',
        style: TextStyle(
          color: AppColors.navyMuted,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

