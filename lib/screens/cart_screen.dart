import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cart_item.dart';
import '../providers/auth_provider.dart';
import '../providers/market_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/product_image.dart';
import 'auth/phone_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key, this.onGoToCatalog});

  final VoidCallback? onGoToCatalog;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MarketProvider>();
    final items = provider.cartItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Корзина', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (items.isNotEmpty)
            TextButton.icon(
              onPressed: () => _confirmClear(context, provider),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Очистить'),
            ),
        ],
      ),
      body: items.isEmpty
          ? _EmptyCart(onGoToCatalog: onGoToCatalog)
          : _CartList(items: items, provider: provider),
    );
  }

  void _confirmClear(BuildContext context, MarketProvider provider) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Очистить корзину?'),
        content: const Text('Все товары будут удалены из корзины.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              provider.clearCart();
              Navigator.pop(ctx);
            },
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart({this.onGoToCatalog});

  final VoidCallback? onGoToCatalog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 72,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Корзина пуста',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Добавьте товары из каталога',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            if (onGoToCatalog != null)
              FilledButton.icon(
                onPressed: onGoToCatalog,
                icon: const Icon(Icons.grid_view_rounded),
                label: const Text('Перейти в каталог'),
              ),
          ],
        ),
      ),
    );
  }
}

class _CartList extends StatelessWidget {
  const _CartList({required this.items, required this.provider});

  final List<CartItem> items;
  final MarketProvider provider;

  @override
  Widget build(BuildContext context) {
    final total = provider.cartTotalAmount;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            // Bottom padding ensures the last item scrolls fully above the
            // summary bar without a huge gap: use a fixed 12dp breathing room.
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            itemCount: items.length,
            itemBuilder: (context, index) => _CartItemCard(
              item: items[index],
              provider: provider,
            ),
          ),
        ),
        _SummaryBar(total: total, provider: provider),
      ],
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({required this.item, required this.provider});

  final CartItem item;
  final MarketProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final atMax = item.quantity >= item.product.stockQuantity;

    return Container(
      key: Key('cart-item-${item.product.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image ─────────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 76,
              height: 76,
              child: ProductImage(imageUrl: item.product.imageUrl),
            ),
          ),
          const SizedBox(width: 10),
          // ── Content ───────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row + delete button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.product.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: IconButton(
                        key: Key('cart-del-${item.product.id}'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Удалить',
                        icon: const Icon(Icons.close_rounded, size: 16),
                        color: AppColors.navyMuted,
                        onPressed: () => provider.removeFromCart(item.product.id),
                      ),
                    ),
                  ],
                ),
                // Package info
                if (item.product.packageInfo.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.product.packageInfo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.navyMuted,
                    ),
                  ),
                ],
                // Unit price
                const SizedBox(height: 4),
                Text(
                  '${item.product.price.toStringAsFixed(0)} ₸',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.navyMuted,
                  ),
                ),
                const SizedBox(height: 8),
                // Qty selector + line total
                Row(
                  children: [
                    _QtySelector(
                      item: item,
                      atMax: atMax,
                      onDecrement: () => provider.updateQuantity(
                        item.product.id,
                        item.quantity - 1,
                      ),
                      onIncrement: atMax
                          ? null
                          : () => provider.updateQuantity(
                              item.product.id,
                              item.quantity + 1,
                            ),
                    ),
                    const Spacer(),
                    Text(
                      '${item.totalPrice.toStringAsFixed(0)} ₸',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QtySelector extends StatelessWidget {
  const _QtySelector({
    required this.item,
    required this.atMax,
    required this.onDecrement,
    required this.onIncrement,
  });

  final CartItem item;
  final bool atMax;
  final VoidCallback onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key('cart-dec-${item.product.id}'),
            icon: const Icon(Icons.remove_rounded, size: 16),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            onPressed: onDecrement,
          ),
          SizedBox(
            width: 28,
            child: Text(
              '${item.quantity}',
              key: Key('cart-qty-${item.product.id}'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          IconButton(
            key: Key('cart-inc-${item.product.id}'),
            icon: const Icon(Icons.add_rounded, size: 16),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            onPressed: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.total, required this.provider});

  final double total;
  final MarketProvider provider;

  void _onCheckout(BuildContext context) {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PhoneScreen()),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Оформление заказа скоро будет доступно'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Товары',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.navyMuted,
                  ),
                ),
                Text(
                  '${total.toStringAsFixed(0)} ₸',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('cart-checkout-btn'),
              onPressed: () => _onCheckout(context),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Оформить заказ', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
