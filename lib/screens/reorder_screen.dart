import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../models/product.dart';
import '../providers/market_provider.dart';
import '../services/catalog_api.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/app_chip.dart';
import '../widgets/ui/error_state.dart';
import '../widgets/ui/skeleton.dart';
import 'cart_screen.dart';
import 'product_catalog_screen.dart';

class ReorderScreen extends StatefulWidget {
  const ReorderScreen({super.key, required this.order});

  final OrderSummary order;

  @override
  State<ReorderScreen> createState() => _ReorderScreenState();
}

// ── Per-item state ─────────────────────────────────────────────────────────────

class _ReorderItem {
  _ReorderItem({
    required this.orderItem,
    this.product,
    this.variants,   // non-null when size choice is required
    this.notFound = false,
  })  : isSelected = product != null && product.inStock,
        selectedVariantLabel = null;

  final OrderItem orderItem;

  // Resolved product for a specific size. Null when:
  //   • variants != null  (user must pick a size), or
  //   • notFound = true   (search returned nothing).
  final Product? product;

  // In-stock variants as Product objects (each = specific size).
  // Non-null when product_id was absent / deleted AND multiple sizes exist.
  final List<Product>? variants;

  final bool notFound;

  bool isSelected;

  // Label of the chip the user tapped (matches Product.packageInfo).
  String? selectedVariantLabel;

  // ── Derived ──────────────────────────────────────────────────────────────────

  bool get isAvailable => product != null && product!.inStock;

  bool get needsVariantSelection =>
      variants != null && variants!.isNotEmpty && product == null;

  // True when this item is ready to contribute to the "Add to cart" action.
  bool get isReady =>
      isAvailable ||
      (needsVariantSelection && selectedVariantLabel != null);

  // The product we will add to cart (resolved = specific variant).
  Product? get effectiveProduct {
    if (product != null) return product;
    if (selectedVariantLabel != null && variants != null) {
      final matches =
          variants!.where((v) => v.packageInfo == selectedVariantLabel);
      return matches.isEmpty ? null : matches.first;
    }
    return null;
  }

  int get addQty {
    final p = effectiveProduct;
    if (p == null || !p.inStock) return 0;
    return orderItem.qty.clamp(0, p.stockQuantity);
  }

  bool get priceChanged {
    final p = effectiveProduct;
    if (p == null || !p.inStock) return false;
    return p.price.round() != orderItem.unitPrice;
  }

  String get sizeLabel => effectiveProduct?.packageInfo ?? '';
}

// ── Screen state ───────────────────────────────────────────────────────────────

class _ReorderScreenState extends State<ReorderScreen> {
  late final CatalogApi _api;
  List<_ReorderItem>? _items;
  Object? _error;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _api = CatalogApi();
    _load();
  }

  // ── Loading ──────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _error = null;
      _items = null;
    });
    try {
      final results =
          await Future.wait(widget.order.items.map(_loadOneItem));
      if (mounted) setState(() => _items = results);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<_ReorderItem> _loadOneItem(OrderItem item) async {
    final pid = item.productId;
    if (pid != null && pid.isNotEmpty) {
      try {
        final r = await _api.getProductById(pid);
        // product_id IS the specific size row — no further variant resolution.
        return _ReorderItem(orderItem: item, product: r.product);
      } catch (_) {
        // Product deleted or deactivated → fall through to name search.
      }
    }
    return _searchFallback(item);
  }

  Future<_ReorderItem> _searchFallback(OrderItem item) async {
    final sizeToken = _extractSize(item.name);
    final searchQuery = _cleanName(item.name);

    try {
      final results =
          await _api.getProducts(search: searchQuery, limit: 5);
      if (results.isEmpty) {
        return _ReorderItem(orderItem: item, notFound: true);
      }

      // Get full variant list from the first (most relevant) search hit.
      final (:product, :variants) =
          await _api.getProductById(results.first.id);

      // Build a flat list of in-stock Product objects, one per size.
      final allVariants = <Product>[
        if (product.inStock) product,
        ...variants
            .where((v) => v.inStock)
            .map((v) => _variantToProduct(v, product)),
      ];

      // All out of stock → show the base product as unavailable.
      if (allVariants.isEmpty) {
        return _ReorderItem(orderItem: item, product: product);
      }

      // Try to match by size extracted from the order item name.
      if (sizeToken != null) {
        final upper = sizeToken.toUpperCase();
        final bySize = allVariants
            .where((p) => p.packageInfo.toUpperCase() == upper);
        if (bySize.isNotEmpty) {
          return _ReorderItem(orderItem: item, product: bySize.first);
        }
      }

      // Single variant → use it regardless.
      if (allVariants.length == 1) {
        return _ReorderItem(orderItem: item, product: allVariants.first);
      }

      // Multiple variants, size unknown → ask the user.
      return _ReorderItem(orderItem: item, variants: allVariants);
    } catch (_) {
      return _ReorderItem(orderItem: item, notFound: true);
    }
  }

  // ── Derived state ────────────────────────────────────────────────────────────

  int get _selectedCount =>
      _items?.where((i) => i.isSelected && i.isReady).length ?? 0;

  // Items that can't be added at all (out of stock OR not found),
  // excluding items that simply need a size choice.
  bool get _hasUnavailable =>
      _items?.any((i) => !i.isAvailable && !i.needsVariantSelection) ??
      false;

  bool get _allUnavailable =>
      (_items?.isNotEmpty ?? false) &&
      _items!.every((i) => !i.isAvailable && !i.needsVariantSelection);

  // ── Actions ──────────────────────────────────────────────────────────────────

  Future<void> _addToCart() async {
    final ready =
        _items!.where((i) => i.isSelected && i.isReady).toList();
    if (ready.isEmpty) return;

    setState(() => _isAdding = true);
    final market = context.read<MarketProvider>();
    for (final ri in ready) {
      final p = ri.effectiveProduct;
      if (p != null && ri.addQty > 0) {
        market.addToCartWithQty(p, ri.addQty);
      }
    }
    setState(() => _isAdding = false);
    if (!mounted) return;

    final n = ready.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Добавлено $n ${_itemWord(n)} в корзину'),
        action: SnackBarAction(
          label: 'Открыть',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  CartScreen(onGoToCatalog: () => Navigator.pop(context)),
            ),
          ),
        ),
      ),
    );
    Navigator.pop(context);
  }

  void _openReplacement() {
    final unavailable = _items
            ?.where((i) => !i.isAvailable && !i.needsVariantSelection)
            .toList() ??
        [];
    final category = unavailable
        .map((i) => i.product?.category ?? '')
        .firstWhere((c) => c.isNotEmpty, orElse: () => '');

    final market = context.read<MarketProvider>();
    if (category.isNotEmpty) {
      market.setSelectedCategory(category);
      market.loadProducts();
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProductCatalogScreen()),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Повторить заказ',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            Text(
              'Заказ №${widget.order.orderNumber}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.navyMuted,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: ErrorState(
          onRetry: _load,
          onBack: () => Navigator.pop(context),
        ),
      );
    }
    if (_items == null) return _buildSkeleton();
    if (_allUnavailable) return _buildAllUnavailable();
    return _buildLoaded();
  }

  Widget _buildLoaded() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            children: [
              const Text(
                'Проверьте товары',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              for (final item in _items!) ...[
                _buildItemCard(item),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              const Text(
                'Цены и наличие могут измениться. '
                'В корзину добавим только доступные товары.',
                style: TextStyle(
                  color: AppColors.navyMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildItemCard(_ReorderItem ri) {
    final displayName = ri.sizeLabel.isNotEmpty
        ? '${ri.orderItem.name}, ${ri.sizeLabel}'
        : ri.orderItem.name;

    final showChips = ri.needsVariantSelection;
    final checkEnabled = ri.isAvailable || showChips;
    final checkActive = ri.isSelected && checkEnabled;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardBorder,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: (ri.isAvailable || showChips)
                            ? AppColors.navy
                            : AppColors.navyMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildSubtitle(ri),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Indicator
              _buildIndicator(ri, checkActive, checkEnabled),
            ],
          ),

          // Size ChipGroup (only for needsVariantSelection state)
          if (showChips) ...[
            const SizedBox(height: 10),
            ChipGroup(
              padding: EdgeInsets.zero,
              items:
                  ri.variants!.map((v) => v.packageInfo).toList(),
              selected: ri.selectedVariantLabel,
              onSelected: (label) => setState(() {
                ri.selectedVariantLabel = label;
                ri.isSelected = true;
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubtitle(_ReorderItem ri) {
    if (ri.notFound) {
      return const Text(
        'Не удалось найти товар',
        style: TextStyle(color: AppColors.navyMuted, fontSize: 12),
      );
    }
    if (ri.needsVariantSelection) {
      return Text(
        ri.selectedVariantLabel == null
            ? 'Выберите размер'
            : 'Текущая цена · ${formatMoney(ri.effectiveProduct!.price.round())}',
        style: TextStyle(
          color: ri.selectedVariantLabel == null
              ? AppColors.purple
              : AppColors.navyMuted,
          fontSize: 12,
          fontWeight: ri.selectedVariantLabel == null
              ? FontWeight.w600
              : FontWeight.w400,
        ),
      );
    }
    if (ri.isAvailable) {
      if (ri.priceChanged) {
        return Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 2,
          children: [
            Text(
              'Было ${formatMoney(ri.orderItem.unitPrice)}',
              style: const TextStyle(
                color: AppColors.navyMuted,
                fontSize: 12,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const Text(
              '→',
              style:
                  TextStyle(color: AppColors.navyMuted, fontSize: 12),
            ),
            Text(
              'сейчас ${formatMoney(ri.product!.price.round())}',
              style: const TextStyle(
                color: AppColors.purple,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      }
      return Text(
        'Текущая цена · ${formatMoney(ri.product!.price.round())}',
        style: const TextStyle(color: AppColors.navyMuted, fontSize: 12),
      );
    }
    // Found but out of stock
    return const Text(
      'Нет в наличии',
      style: TextStyle(color: AppColors.navyMuted, fontSize: 12),
    );
  }

  Widget _buildIndicator(_ReorderItem ri, bool active, bool enabled) {
    if (!enabled) {
      // Not found or out of stock → grey dash
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.remove_rounded,
          color: AppColors.navyMuted,
          size: 18,
        ),
      );
    }
    // Available or needs-variant → animated checkbox
    return GestureDetector(
      onTap: () => setState(() => ri.isSelected = !ri.isSelected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: active ? AppColors.purple : Colors.transparent,
          border: Border.all(
            color: active ? AppColors.purple : AppColors.border,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: active
            ? const Icon(Icons.check_rounded,
                color: Colors.white, size: 18)
            : null,
      ),
    );
  }

  Widget _buildBottomBar() {
    final n = _selectedCount;
    final label = n == 0
        ? 'Выберите товары'
        : 'Добавить $n ${_itemWord(n)} в корзину';

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        MediaQuery.paddingOf(context).bottom + AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            label: label,
            variant: n == 0
                ? AppButtonVariant.disabled
                : AppButtonVariant.primary,
            loading: _isAdding,
            fullWidth: true,
            onPressed: n > 0 ? _addToCart : null,
          ),
          if (_hasUnavailable) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Выбрать замену',
              variant: AppButtonVariant.secondary,
              fullWidth: true,
              onPressed: _openReplacement,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Skeleton.rect(width: 160, height: 20),
        const SizedBox(height: 16),
        for (int i = 0; i < widget.order.items.length; i++) ...[
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.cardBorder,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton.rect(height: 14, radius: 4),
                      const SizedBox(height: 6),
                      Skeleton.rect(width: 120, height: 12, radius: 4),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Skeleton.rect(width: 28, height: 28, radius: 8),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildAllUnavailable() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x3l,
          vertical: AppSpacing.x3l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 72, color: AppColors.navyMuted),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Товары из этого заказа\nсейчас недоступны',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.x2l),
            AppButton(
              label: 'Выбрать замену',
              variant: AppButtonVariant.secondary,
              fullWidth: true,
              onPressed: _openReplacement,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

// Sizes as stored in the backend ProductSize enum, longest-first for
// correct suffix matching (XXXL before XXL before XL).
const _kSizeTokens = ['XXXL', 'XXL', 'XL', 'NB', 'ONE', 'S', 'M', 'L'];

String? _extractSize(String name) {
  final trimmed = name.trim().toUpperCase();
  for (final size in _kSizeTokens) {
    if (trimmed.endsWith(' $size')) return size;
  }
  return null;
}

String _cleanName(String name) {
  final trimmed = name.trim();
  final upper = trimmed.toUpperCase();
  for (final size in _kSizeTokens) {
    if (upper.endsWith(' $size')) {
      return trimmed.substring(0, trimmed.length - size.length - 1).trim();
    }
  }
  return trimmed;
}

// Synthesises a full Product from a ProductVariant + base product context.
// Avoids an extra API call per variant when building the ChipGroup list.
Product _variantToProduct(ProductVariant v, Product base) {
  return Product(
    id: v.id,
    title: base.title,
    description: base.description,
    price: v.price,
    originalPrice: v.originalPrice,
    imageUrl: v.heroUrl ?? base.imageUrl,
    imageUrls:
        v.heroUrl != null ? [v.heroUrl!] : List.unmodifiable(base.imageUrls),
    category: base.category,
    packageInfo: v.size != 'ONE' ? v.size : '',
    inStock: v.inStock,
    stockQuantity: v.stockQty,
    rating: base.rating,
  );
}

String _itemWord(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 19) return 'товаров';
  if (mod10 == 1) return 'товар';
  if (mod10 >= 2 && mod10 <= 4) return 'товара';
  return 'товаров';
}
