import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/market_provider.dart';
import '../providers/wishlist_provider.dart';
import '../services/catalog_api.dart';
import '../theme/app_theme.dart';
import '../widgets/product_image.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.product});

  final Product product;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Product _baseProduct;
  late Product _activeProduct;
  List<ProductVariant> _variants = [];
  int _qty = 1;
  int _galleryPage = 0;
  final _pageCtrl = PageController();

  @override
  void initState() {
    super.initState();
    _baseProduct = widget.product;
    _activeProduct = widget.product;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetail());
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    try {
      final result = await context.read<MarketProvider>().getProductById(_baseProduct.id);
      if (!mounted) return;
      setState(() {
        _baseProduct = result.product;
        _activeProduct = result.product;
        _variants = result.variants;
      });
    } catch (_) {
      // Detail enrichment failed — initial product data is already shown
    }
  }

  void _selectVariant(ProductVariant v) {
    setState(() {
      _activeProduct = _productFromVariant(v);
      _qty = 1;
      _galleryPage = 0;
      _pageCtrl.jumpToPage(0);
    });
  }

  Product _productFromVariant(ProductVariant v) => Product(
        id: v.id,
        title: _baseProduct.title,
        description: _baseProduct.description,
        price: v.price,
        originalPrice: v.originalPrice,
        imageUrl: v.heroUrl ?? _baseProduct.imageUrl,
        imageUrls: v.heroUrl != null ? [v.heroUrl!] : _baseProduct.imageUrls,
        specs: _baseProduct.specs,
        category: _baseProduct.category,
        packageInfo: v.size != 'ONE' ? v.size : '',
        inStock: v.inStock,
        stockQuantity: v.stockQty,
        rating: _baseProduct.rating,
      );

  bool get _isCurrentVariant {
    if (_variants.isEmpty) return false;
    return _variants.every((v) => v.id != _activeProduct.id);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MarketProvider>();
    final wishlist = context.watch<WishlistProvider>();
    final isFav = wishlist.isFavorite(_activeProduct.id);
    final cartQty = provider.cartQuantityFor(_activeProduct.id);
    final available = (_activeProduct.stockQuantity - cartQty).clamp(0, _activeProduct.stockQuantity);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: _Gallery(
                imageUrls: _activeProduct.imageUrls,
                fallbackUrl: _activeProduct.imageUrl,
                pageCtrl: _pageCtrl,
                currentPage: _galleryPage,
                onPageChanged: (p) => setState(() => _galleryPage = p),
              ),
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
                onPressed: () async {
                  final token = await context.read<AuthProvider>().getAccessToken();
                  if (!context.mounted) return;
                  context.read<WishlistProvider>().toggle(_activeProduct, accessToken: token);
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PriceRow(product: _activeProduct),
                  const SizedBox(height: 10),
                  _NameRow(product: _activeProduct),
                  const SizedBox(height: 12),
                  _StockRow(product: _activeProduct),
                  if (_variants.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _SizeSelector(
                      activeId: _activeProduct.id,
                      baseProduct: _baseProduct,
                      isBaseCurrent: _isCurrentVariant,
                      variants: _variants,
                      onSelect: _selectVariant,
                    ),
                  ],
                  if (_activeProduct.specs.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _SpecsSection(specs: _activeProduct.specs),
                  ],
                  if (_activeProduct.description.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _DescriptionSection(text: _activeProduct.description),
                  ],
                  const SizedBox(height: 110),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _BottomBar(
        product: _activeProduct,
        qty: _qty,
        available: available,
        onIncrement: _activeProduct.inStock && available > 0 && _qty < available
            ? () => setState(() => _qty++)
            : null,
        onDecrement: _qty > 1 ? () => setState(() => _qty--) : null,
        onAddToCart: _activeProduct.inStock && available > 0 && _qty <= available
            ? () {
                provider.addToCartWithQty(_activeProduct, _qty);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('В корзину: $_qty шт.'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            : null,
        atMax: _activeProduct.inStock && (available == 0 || _qty > available),
      ),
    );
  }
}

// ── Gallery ────────────────────────────────────────────────────────────────────

class _Gallery extends StatelessWidget {
  const _Gallery({
    required this.imageUrls,
    required this.fallbackUrl,
    required this.pageCtrl,
    required this.currentPage,
    required this.onPageChanged,
  });

  final List<String> imageUrls;
  final String fallbackUrl;
  final PageController pageCtrl;
  final int currentPage;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final urls = imageUrls.isNotEmpty ? imageUrls : (fallbackUrl.isNotEmpty ? [fallbackUrl] : <String>[]);
    if (urls.isEmpty) {
      return Container(
        color: AppColors.purpleSoft,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, size: 64, color: AppColors.navyMuted),
      );
    }
    if (urls.length == 1) {
      return ProductImage(imageUrl: urls.first);
    }
    return Stack(
      children: [
        PageView.builder(
          controller: pageCtrl,
          onPageChanged: onPageChanged,
          itemCount: urls.length,
          itemBuilder: (_, i) => ProductImage(imageUrl: urls[i]),
        ),
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              urls.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == currentPage ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == currentPage
                      ? AppColors.purple
                      : Colors.white.withValues(alpha: .6),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Price row ──────────────────────────────────────────────────────────────────

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final hasSale = product.originalPrice != null &&
        product.originalPrice! > product.price;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${product.price.toStringAsFixed(0)} ₸',
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (hasSale) ...[
          const SizedBox(width: 10),
          Text(
            '${product.originalPrice!.toStringAsFixed(0)} ₸',
            style: const TextStyle(
              color: AppColors.navyMuted,
              fontSize: 15,
              decoration: TextDecoration.lineThrough,
              decorationColor: AppColors.navyMuted,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Name row ───────────────────────────────────────────────────────────────────

class _NameRow extends StatelessWidget {
  const _NameRow({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product.title,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        if (product.packageInfo.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            product.packageInfo,
            style: const TextStyle(color: AppColors.navyMuted, fontSize: 14),
          ),
        ],
      ],
    );
  }
}

// ── Stock row ──────────────────────────────────────────────────────────────────

class _StockRow extends StatelessWidget {
  const _StockRow({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final inStock = product.inStock;
    return Row(
      children: [
        Icon(
          inStock ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
          size: 17,
          color: inStock ? const Color(0xFF23804A) : Colors.red.shade700,
        ),
        const SizedBox(width: 6),
        Text(
          inStock
              ? 'В наличии: ${product.stockQuantity} шт.'
              : 'Нет в наличии',
          style: TextStyle(
            color: inStock ? const Color(0xFF23804A) : Colors.red.shade700,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Size selector ──────────────────────────────────────────────────────────────

class _SizeSelector extends StatelessWidget {
  const _SizeSelector({
    required this.activeId,
    required this.baseProduct,
    required this.isBaseCurrent,
    required this.variants,
    required this.onSelect,
  });

  final String activeId;
  final Product baseProduct;
  final bool isBaseCurrent;
  final List<ProductVariant> variants;
  final ValueChanged<ProductVariant> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Размер',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SizeChip(
              label: baseProduct.packageInfo.isNotEmpty
                  ? baseProduct.packageInfo
                  : 'ONE',
              isSelected: activeId == baseProduct.id,
              inStock: baseProduct.inStock,
              onTap: isBaseCurrent
                  ? null
                  : () => onSelect(ProductVariant(
                        id: baseProduct.id,
                        size: baseProduct.packageInfo.isNotEmpty
                            ? baseProduct.packageInfo
                            : 'ONE',
                        price: baseProduct.price,
                        originalPrice: baseProduct.originalPrice,
                        stockQty: baseProduct.stockQuantity,
                        heroUrl: baseProduct.imageUrl.isNotEmpty
                            ? baseProduct.imageUrl
                            : null,
                      )),
            ),
            for (final v in variants)
              _SizeChip(
                label: v.size != 'ONE' ? v.size : 'ONE',
                isSelected: activeId == v.id,
                inStock: v.inStock,
                onTap: activeId == v.id ? null : () => onSelect(v),
              ),
          ],
        ),
      ],
    );
  }
}

class _SizeChip extends StatelessWidget {
  const _SizeChip({
    required this.label,
    required this.isSelected,
    required this.inStock,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool inStock;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.purple : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.purple : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : inStock
                    ? AppColors.navy
                    : AppColors.navyMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            decoration: inStock ? null : TextDecoration.lineThrough,
          ),
        ),
      ),
    );
  }
}

// ── Specs section ──────────────────────────────────────────────────────────────

class _SpecsSection extends StatelessWidget {
  const _SpecsSection({required this.specs});
  final Map<String, dynamic> specs;

  @override
  Widget build(BuildContext context) {
    final entries = specs.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Характеристики',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.cardBorder,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (int i = 0; i < entries.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.border),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          entries[i].key,
                          style: const TextStyle(
                            color: AppColors.navyMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 5,
                        child: Text(
                          '${entries[i].value}',
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Description section ────────────────────────────────────────────────────────

class _DescriptionSection extends StatelessWidget {
  const _DescriptionSection({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Описание',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.navyMuted,
            fontSize: 14,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

// ── Bottom bar ─────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.product,
    required this.qty,
    required this.available,
    required this.onIncrement,
    required this.onDecrement,
    required this.onAddToCart,
    required this.atMax,
  });

  final Product product;
  final int qty;
  final int available;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final VoidCallback? onAddToCart;
  final bool atMax;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
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
                    label: Text(atMax ? 'Максимум в корзине' : 'В корзину'),
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
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
