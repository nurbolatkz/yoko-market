import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/market_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/product_image.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.product});

  final Product product;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _qty = 1;

  Product get _product => widget.product;

  void _increment() {
    if (_qty < _product.stockQuantity) setState(() => _qty++);
  }

  void _decrement() {
    if (_qty > 1) setState(() => _qty--);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<MarketProvider>();
    final isFav = provider.isFavorite(_product.id);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: ProductImage(imageUrl: _product.imageUrl),
            ),
            actions: [
              IconButton(
                tooltip: isFav ? 'Убрать из избранного' : 'В избранное',
                icon: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: .85),
                  child: Icon(
                    isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isFav ? AppColors.purple : Colors.black87,
                    size: 22,
                  ),
                ),
                onPressed: () => provider.toggleFavorite(_product.id),
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_product.category.isNotEmpty)
                    Chip(
                      label: Text(_product.category),
                      backgroundColor: theme.colorScheme.primaryContainer,
                      labelStyle: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    _product.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_product.packageInfo.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      _product.packageInfo,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    '${_product.price.toStringAsFixed(0)} ₸',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        _product.inStock
                            ? Icons.check_circle_outline_rounded
                            : Icons.cancel_outlined,
                        size: 18,
                        color: _product.inStock
                            ? const Color(0xFF23804A)
                            : Colors.red.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _product.inStock
                            ? 'В наличии: ${_product.stockQuantity} шт.'
                            : 'Нет в наличии',
                        style: TextStyle(
                          color: _product.inStock
                              ? const Color(0xFF23804A)
                              : Colors.red.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (_product.description.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Описание',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _product.description,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _BottomBar(
        qty: _qty,
        onIncrement: _product.inStock && _qty < _product.stockQuantity
            ? _increment
            : null,
        onDecrement: _qty > 1 ? _decrement : null,
        onAddToCart: _product.inStock
            ? () {
                provider.addToCartWithQty(_product, _qty);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('В корзину: $_qty шт.'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            : null,
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.qty,
    required this.onIncrement,
    required this.onDecrement,
    required this.onAddToCart,
  });

  final int qty;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final VoidCallback? onAddToCart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const Key('detail-qty-dec'),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.remove_rounded),
                    onPressed: onDecrement,
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '$qty',
                      key: const Key('detail-qty-label'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('detail-qty-inc'),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.add_rounded),
                    onPressed: onIncrement,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                key: const Key('detail-add-to-cart'),
                onPressed: onAddToCart,
                icon: const Icon(Icons.shopping_cart_outlined),
                label: const Text('В корзину'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
