import 'dart:math' show max;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/market_provider.dart';
import '../providers/wishlist_provider.dart';
import '../screens/delivery_info_screen.dart';
import '../services/catalog_api.dart';
import '../services/loyalty_api.dart';
import '../services/store_settings_api.dart';
import '../theme/app_theme.dart';
import '../utils/dio_error.dart';
import '../utils/format.dart';
import '../widgets/product_image.dart';
import '../widgets/ui/error_state.dart';
import '../widgets/ui/nav_row.dart';
import '../widgets/ui/product_card.dart';
import '../widgets/ui/size_guide_sheet.dart';
import '../widgets/ui/skeleton.dart';
import '../widgets/ui/specs_highlight.dart';

// ── Review data ────────────────────────────────────────────────────────────────

class _ReviewItem {
  _ReviewItem({
    required this.id,
    required this.authorName,
    required this.rating,
    this.text,
    required this.createdAt,
    required this.isVerified,
  });

  final String id;
  final String authorName;
  final int rating;
  final String? text;
  final DateTime createdAt;
  final bool isVerified;

  static _ReviewItem fromJson(Map<String, dynamic> j) => _ReviewItem(
        id: j['id'] as String? ?? '',
        authorName: j['author_name'] as String? ?? 'Покупатель',
        rating: (j['rating'] as num?)?.toInt() ?? 5,
        text: j['text'] as String?,
        createdAt:
            DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
        isVerified: j['is_verified'] as bool? ?? false,
      );
}

// ── Main screen ────────────────────────────────────────────────────────────────

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
  int _galleryPage = 0;
  final _pageCtrl = PageController();
  bool _detailLoading = true;
  String? _detailError;

  LoyaltyRules? _loyaltyRules;
  int _deliveryFreeFrom = 10000;
  List<Product> _relatedProducts = [];
  final _scrollCtrl = ScrollController();
  final _reviewsKey = GlobalKey();
  final _loyaltyApi = createLoyaltyApi();
  final _settingsApi = createStoreSettingsApi();
  late final CatalogApi _catalogApi;

  @override
  void initState() {
    super.initState();
    _baseProduct = widget.product;
    _activeProduct = widget.product;
    _catalogApi = CatalogApi();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetail());
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _detailLoading = true;
      _detailError = null;
    });
    try {
      final result =
          await context.read<MarketProvider>().getProductById(_baseProduct.id);
      if (!mounted) return;
      setState(() {
        _baseProduct = result.product;
        _activeProduct = result.product;
        _variants = result.variants;
        _detailLoading = false;
      });
      _loadSupportingData();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _detailLoading = false;
        _detailError = networkErrorMessage(e);
      });
    }
  }

  Future<void> _loadSupportingData() async {
    final category = _activeProduct.category;
    final productId = _activeProduct.id;

    await Future.wait([
      _loyaltyApi.getRules().then((r) {
        if (mounted) setState(() => _loyaltyRules = r);
      }).catchError((_) {}),
      _settingsApi.getSettings().then((s) {
        if (mounted) setState(() => _deliveryFreeFrom = s.deliveryFreeFrom);
      }).catchError((_) {}),
      _catalogApi.getProducts(category: category, limit: 10).then((products) {
        if (mounted) {
          setState(() => _relatedProducts =
              products.where((p) => p.id != productId).toList());
        }
      }).catchError((_) {}),
    ]);
  }

  void _selectVariant(ProductVariant v) {
    setState(() {
      _activeProduct = _productFromVariant(v);
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
        reviewCount: _baseProduct.reviewCount,
      );

  bool get _isCurrentVariant {
    if (_variants.isEmpty) return false;
    return _variants.every((v) => v.id != _activeProduct.id);
  }

  String? get _brand {
    for (final key in ['brand', 'Brand', 'Бренд']) {
      final v = _activeProduct.specs[key];
      if (v is String && v.isNotEmpty) return v.toUpperCase();
    }
    return null;
  }

  int get _discountPct {
    final op = _activeProduct.originalPrice;
    if (op == null || op <= _activeProduct.price) return 0;
    return ((op - _activeProduct.price) / op * 100).round();
  }

  static String? _weightForSize(String size) {
    const table = {
      'NB': 'до 5 кг',
      'S': '3–8 кг',
      'M': '6–11 кг',
      'L': '9–18 кг',
      'XL': '11–25 кг',
      'XXL': '13+ кг',
    };
    return table[size.trim().toUpperCase()];
  }

  List<SpecHighlightItem> get _highlightSpecs {
    final items = <SpecHighlightItem>[];
    final specs = _activeProduct.specs;

    // 1. Count per package
    final countVal = specs['qty'] ??
        specs['count'] ??
        specs['Количество'] ??
        specs['quantity'];
    if (countVal != null) {
      items.add(SpecHighlightItem(
        icon: Icons.inventory_2_outlined,
        value: '$countVal шт',
        label: 'в упаковке',
      ));
    } else if (_activeProduct.packageInfo.isNotEmpty) {
      final match = RegExp(r'\d+').firstMatch(_activeProduct.packageInfo);
      if (match != null) {
        items.add(SpecHighlightItem(
          icon: Icons.inventory_2_outlined,
          value: '${match.group(0)} шт',
          label: 'в упаковке',
        ));
      }
    }

    // 2. Weight range
    final weightVal = specs['weight_range'] ??
        specs['Вес ребёнка'] ??
        specs['weight'] ??
        specs['Вес'];
    if (weightVal != null) {
      items.add(SpecHighlightItem(
        icon: Icons.monitor_weight_outlined,
        value: '$weightVal',
        label: 'вес ребёнка',
      ));
    } else if (_variants.isNotEmpty) {
      final w = _weightForSize(_activeProduct.packageInfo.isNotEmpty
          ? _activeProduct.packageInfo
          : (_variants.isNotEmpty ? _variants.first.size : ''));
      if (w != null) {
        items.add(SpecHighlightItem(
          icon: Icons.monitor_weight_outlined,
          value: w,
          label: 'вес ребёнка',
        ));
      }
    }

    // 3. Any other spec
    const usedKeys = {
      'qty', 'count', 'Количество', 'quantity',
      'weight_range', 'Вес ребёнка', 'weight', 'Вес',
      'brand', 'Brand', 'Бренд',
    };
    for (final entry in specs.entries) {
      if (items.length >= 3) break;
      if (usedKeys.contains(entry.key)) continue;
      if (entry.value == null || '${entry.value}'.isEmpty) continue;
      items.add(SpecHighlightItem(
        icon: Icons.info_outline_rounded,
        value: '${entry.value}',
        label: entry.key,
      ));
    }

    return items.take(3).toList();
  }

  void _scrollToReviews() {
    final ctx = _reviewsKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      alignment: 0.1,
    );
  }

  void _share() {
    final domain = AppConfig.inviteDomain;
    if (domain.isEmpty) return;
    SharePlus.instance.share(ShareParams(text: '$domain/products/${_activeProduct.id}'));
  }

  Future<void> _toggleFavorite() async {
    final wishlist = context.read<WishlistProvider>();
    final auth = context.read<AuthProvider>();
    final token = await auth.getAccessToken();
    if (!mounted) return;
    wishlist.toggle(_activeProduct, accessToken: token);
  }

  @override
  Widget build(BuildContext context) {
    if (_detailLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const _ProductDetailSkeleton(),
      );
    }
    if (_detailError != null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        backgroundColor: AppColors.background,
        body: Center(
          child: ErrorState(
            message: _detailError,
            onRetry: _loadDetail,
            onBack: () => Navigator.pop(context),
          ),
        ),
      );
    }

    final provider = context.watch<MarketProvider>();
    final wishlist = context.watch<WishlistProvider>();
    final isFav = wishlist.isFavorite(_activeProduct.id);
    final cartQty = provider.cartQuantityFor(_activeProduct.id);
    final available = (_activeProduct.stockQuantity - cartQty)
        .clamp(0, _activeProduct.stockQuantity);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          // 1. Gallery
          SliverAppBar(
            expandedHeight: 340,
            pinned: false,
            stretch: false,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            toolbarHeight: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: _GalleryBlock(
                imageUrls: _activeProduct.imageUrls,
                fallbackUrl: _activeProduct.imageUrl,
                pageCtrl: _pageCtrl,
                currentPage: _galleryPage,
                onPageChanged: (p) => setState(() => _galleryPage = p),
                isFav: isFav,
                onFavToggle: _toggleFavorite,
                onShare: AppConfig.inviteDomain.isNotEmpty ? _share : null,
                discountPct: _discountPct,
                onBack: () => Navigator.pop(context),
              ),
              stretchModes: const [],
            ),
          ),
          // 2. Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand
                  if (_brand != null) ...[
                    Text(
                      _brand!,
                      style: const TextStyle(
                        color: AppColors.purple,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  // Title
                  Text(
                    _activeProduct.title,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Rating row
                  _RatingRow(
                    product: _activeProduct,
                    onTapReviews: _scrollToReviews,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Price block
                  _PriceBlock(product: _activeProduct),
                  const SizedBox(height: AppSpacing.sm),
                  // YoCoin badge
                  if (_loyaltyRules != null &&
                      _loyaltyRules!.defaultCashbackPct > 0)
                    _YoCoinBadge(
                      price: _activeProduct.price,
                      cashbackPct: _loyaltyRules!.defaultCashbackPct,
                    ),
                  // Size selector
                  if (_variants.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.x2l),
                    _SizeSelector(
                      activeId: _activeProduct.id,
                      baseProduct: _baseProduct,
                      isBaseCurrent: _isCurrentVariant,
                      variants: _variants,
                      onSelect: _selectVariant,
                    ),
                  ],
                  // Key specs
                  if (_highlightSpecs.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.x2l),
                    SpecsHighlight(items: _highlightSpecs),
                  ],
                  // Delivery
                  const SizedBox(height: AppSpacing.x2l),
                  _DeliveryRow(deliveryFreeFrom: _deliveryFreeFrom),
                  // Description
                  if (_activeProduct.description.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.x2l),
                    _DescriptionSection(text: _activeProduct.description),
                  ],
                  // Specs table
                  if (_activeProduct.specs.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.x2l),
                    _SpecsSection(specs: _activeProduct.specs),
                  ],
                  // Reviews
                  const SizedBox(height: AppSpacing.x2l),
                  Container(
                    key: _reviewsKey,
                    child: _ReviewsSection(productId: _activeProduct.id),
                  ),
                  // Related products
                  if (_relatedProducts.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.x2l),
                    _RelatedProducts(
                      products: _relatedProducts,
                      onTap: (p) => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(product: p)),
                      ),
                      provider: provider,
                    ),
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
        cartQty: cartQty,
        available: available,
        onAddToCart: _activeProduct.inStock && available > 0
            ? () {
                HapticFeedback.lightImpact();
                provider.addToCartWithQty(_activeProduct, 1);
              }
            : null,
        onIncrement: _activeProduct.inStock && available > 0
            ? () => provider.addToCartWithQty(_activeProduct, 1)
            : null,
        onDecrement: cartQty > 0
            ? () => provider.updateQuantity(_activeProduct.id, cartQty - 1)
            : null,
      ),
    );
  }
}

// ── Gallery block ──────────────────────────────────────────────────────────────

class _GalleryBlock extends StatelessWidget {
  const _GalleryBlock({
    required this.imageUrls,
    required this.fallbackUrl,
    required this.pageCtrl,
    required this.currentPage,
    required this.onPageChanged,
    required this.isFav,
    required this.onFavToggle,
    required this.onShare,
    required this.discountPct,
    required this.onBack,
  });

  final List<String> imageUrls;
  final String fallbackUrl;
  final PageController pageCtrl;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final bool isFav;
  final VoidCallback onFavToggle;
  final VoidCallback? onShare;
  final int discountPct;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final urls = imageUrls.isNotEmpty
        ? imageUrls
        : (fallbackUrl.isNotEmpty ? [fallbackUrl] : <String>[]);

    return Stack(
      children: [
        // Photo container
        ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          child: Container(
            height: 340,
            color: AppColors.purpleSoft,
            child: urls.isEmpty
                ? Container(
                    color: AppColors.purpleSoft,
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_outlined,
                        size: 64, color: AppColors.navyMuted),
                  )
                : urls.length == 1
                    ? ProductImage(imageUrl: urls.first)
                    : PageView.builder(
                        controller: pageCtrl,
                        onPageChanged: onPageChanged,
                        itemCount: urls.length,
                        itemBuilder: (_, i) => ProductImage(imageUrl: urls[i]),
                      ),
          ),
        ),
        // Dots (only if urls.length > 1)
        if (urls.length > 1)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                urls.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == currentPage ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == currentPage
                        ? AppColors.purple
                        : AppColors.surface.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        // Discount badge
        if (discountPct > 0)
          Positioned(
            bottom: 48,
            left: 20,
            child: _DiscountBadge(pct: discountPct),
          ),
        // Overlay buttons (top)
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CircleOverlayButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: onBack,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CircleOverlayButton(
                      icon: isFav
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      iconColor:
                          isFav ? AppColors.purple : AppColors.navy,
                      onTap: onFavToggle,
                    ),
                    if (onShare != null) ...[
                      const SizedBox(width: 8),
                      _CircleOverlayButton(
                        icon: Icons.share_rounded,
                        onTap: onShare!,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Circle overlay button ──────────────────────────────────────────────────────

class _CircleOverlayButton extends StatelessWidget {
  const _CircleOverlayButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 20,
          color: iconColor ?? AppColors.navy,
        ),
      ),
    );
  }
}

// ── Discount badge ─────────────────────────────────────────────────────────────

class _DiscountBadge extends StatelessWidget {
  const _DiscountBadge({required this.pct});

  final int pct;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.yellow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '−$pct%',
        style: const TextStyle(
          color: AppColors.navy,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ── Rating row ─────────────────────────────────────────────────────────────────

class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.product,
    required this.onTapReviews,
  });

  final Product product;
  final VoidCallback onTapReviews;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Stars(rating: product.rating, size: 15),
        const SizedBox(width: 6),
        if (product.reviewCount > 0) ...[
          Flexible(
            child: Text(
              product.rating.toStringAsFixed(1),
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: GestureDetector(
              onTap: onTapReviews,
              child: Text(
                '${product.reviewCount} ${_pluralReview(product.reviewCount)}',
                style: const TextStyle(
                  color: AppColors.purple,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(width: 1, height: 14, color: AppColors.border),
          const SizedBox(width: 10),
        ],
        _StockBadge(product: product),
      ],
    );
  }

  static String _pluralReview(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'отзыв';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
      return 'отзыва';
    }
    return 'отзывов';
  }
}

// ── Stock badge ────────────────────────────────────────────────────────────────

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final inStock = product.inStock;
    final qty = product.stockQuantity;

    final dotColor = inStock ? AppColors.success : AppColors.navyMuted;
    final String label;
    if (!inStock) {
      label = 'Нет в наличии';
    } else if (qty <= 5) {
      label = 'Осталось $qty шт';
    } else {
      label = 'В наличии';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: dotColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Price block ────────────────────────────────────────────────────────────────

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final hasSale =
        product.originalPrice != null && product.originalPrice! > product.price;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          formatMoney(product.price.round()),
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (hasSale) ...[
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              formatMoney(product.originalPrice!.round()),
              style: const TextStyle(
                color: AppColors.navyMuted,
                fontSize: 15,
                decoration: TextDecoration.lineThrough,
                decorationColor: AppColors.navyMuted,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── YoCoin badge ───────────────────────────────────────────────────────────────

class _YoCoinBadge extends StatelessWidget {
  const _YoCoinBadge({required this.price, required this.cashbackPct});

  final double price;
  final int cashbackPct;

  @override
  Widget build(BuildContext context) {
    final n = max(1, (price * cashbackPct / 100).round());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.purpleSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stars_rounded, size: 16, color: AppColors.purple),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '+$n YoCoin за покупку',
              style: const TextStyle(
                color: AppColors.purple,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
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

  static String? _weightForSizeStatic(String size) {
    const table = {
      'NB': 'до 5 кг',
      'S': '3–8 кг',
      'M': '6–11 кг',
      'L': '9–18 кг',
      'XL': '11–25 кг',
      'XXL': '13+ кг',
    };
    return table[size.trim().toUpperCase()];
  }

  String get _selectedLabel {
    for (final v in variants) {
      if (v.id == activeId) return v.size != 'ONE' ? v.size : 'ONE';
    }
    return baseProduct.packageInfo.isNotEmpty ? baseProduct.packageInfo : 'ONE';
  }

  @override
  Widget build(BuildContext context) {
    // Hide the base chip when it's ONE and there are other variants
    final showBase =
        !(variants.isNotEmpty && baseProduct.packageInfo.isEmpty);

    // Find selected variant for summary
    ProductVariant? selectedVariant;
    for (final v in variants) {
      if (v.id == activeId) {
        selectedVariant = v;
        break;
      }
    }

    final summaryParts = <String>[];
    if (selectedVariant != null) {
      if (selectedVariant.size != 'ONE') {
        summaryParts.add(selectedVariant.size);
      }
      final w = _weightForSizeStatic(selectedVariant.size);
      if (w != null) summaryParts.add(w);
      if (selectedVariant.stockQty > 0) {
        summaryParts.add('${selectedVariant.stockQty} шт');
      }
    }
    final summary = summaryParts.join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Размер',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (activeId != baseProduct.id) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '— выбран: $_selectedLabel',
                  style: const TextStyle(
                    color: AppColors.purple,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const Spacer(),
            TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) =>
                    SizeGuideSheet(specs: baseProduct.specs),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Как подобрать?',
                style: TextStyle(
                  color: AppColors.purple,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (showBase)
              _SizeChip(
                label: baseProduct.packageInfo.isNotEmpty
                    ? baseProduct.packageInfo
                    : 'ONE',
                weight: _weightForSizeStatic(
                  baseProduct.packageInfo.isNotEmpty
                      ? baseProduct.packageInfo
                      : 'ONE',
                ),
                price: baseProduct.price,
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
                weight: _weightForSizeStatic(v.size),
                price: v.price,
                isSelected: activeId == v.id,
                inStock: v.inStock,
                onTap: activeId == v.id ? null : () => onSelect(v),
              ),
          ],
        ),
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            summary,
            style: const TextStyle(
              color: AppColors.navyMuted,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}

class _SizeChip extends StatelessWidget {
  const _SizeChip({
    required this.label,
    required this.price,
    required this.isSelected,
    required this.inStock,
    required this.onTap,
    this.weight,
  });

  final String label;
  final String? weight;
  final double price;
  final bool isSelected;
  final bool inStock;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: inStock ? 1.0 : 0.45,
      child: GestureDetector(
        onTap: inStock ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.purple : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.purple : AppColors.border,
              width: isSelected ? 2 : 1.5,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : inStock
                          ? AppColors.navy
                          : AppColors.navyMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  decoration: inStock ? null : TextDecoration.lineThrough,
                ),
              ),
              if (weight != null) ...[
                const SizedBox(height: 2),
                Text(
                  weight!,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.75)
                        : AppColors.navyMuted,
                    fontSize: 11,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 2),
                Text(
                  '${price.toStringAsFixed(0)} ₸',
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.85)
                        : AppColors.navyMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Delivery row ───────────────────────────────────────────────────────────────

class _DeliveryRow extends StatelessWidget {
  const _DeliveryRow({required this.deliveryFreeFrom});

  final int deliveryFreeFrom;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardBorder,
        border: Border.all(color: AppColors.border),
      ),
      child: NavRow(
        leading: const Icon(Icons.local_shipping_outlined,
            color: AppColors.purple, size: 22),
        title: 'Бесплатная доставка от ${formatMoney(deliveryFreeFrom)}',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DeliveryInfoScreen()),
        ),
      ),
    );
  }
}

// ── Description section ────────────────────────────────────────────────────────

class _DescriptionSection extends StatefulWidget {
  const _DescriptionSection({required this.text});
  final String text;

  @override
  State<_DescriptionSection> createState() => _DescriptionSectionState();
}

class _DescriptionSectionState extends State<_DescriptionSection> {
  bool _expanded = false;
  static const _collapsedMaxLines = 3;

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
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: Text(
            widget.text,
            maxLines: _collapsedMaxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.navyMuted,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          secondChild: Text(
            widget.text,
            style: const TextStyle(
              color: AppColors.navyMuted,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ),
        LayoutBuilder(builder: (context, constraints) {
          final tp = TextPainter(
            text: TextSpan(
              text: widget.text,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
            maxLines: _collapsedMaxLines,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: constraints.maxWidth);
          if (!tp.didExceedMaxLines) return const SizedBox.shrink();
          return GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _expanded ? 'Свернуть' : 'Читать полностью',
                style: const TextStyle(
                  color: AppColors.purple,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Specs section ──────────────────────────────────────────────────────────────

class _SpecsSection extends StatelessWidget {
  const _SpecsSection({required this.specs});
  final Map<String, dynamic> specs;

  static const _brandKeys = {'brand', 'Brand', 'Бренд'};

  @override
  Widget build(BuildContext context) {
    final entries =
        specs.entries.where((e) => !_brandKeys.contains(e.key)).toList();
    if (entries.isEmpty) return const SizedBox.shrink();

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
                if (i > 0)
                  const Divider(height: 1, color: AppColors.border),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
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

// ── Reviews section ────────────────────────────────────────────────────────────

class _ReviewsSection extends StatefulWidget {
  const _ReviewsSection({required this.productId});
  final String productId;

  @override
  State<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<_ReviewsSection> {
  final _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      responseType: ResponseType.json,
    ),
  );

  List<_ReviewItem> _reviews = [];
  bool _loading = true;
  bool _showAll = false;
  bool _hasReviewed = false;
  bool _submitting = false;
  bool _success = false;
  int _selectedRating = 0;
  final _textCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final resp =
          await _dio.get<dynamic>('/products/${widget.productId}/reviews');
      final list = (resp.data as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      final prefs = await SharedPreferences.getInstance();
      final hasReviewed =
          prefs.getBool('reviewed_${widget.productId}') ?? false;
      if (!mounted) return;
      setState(() {
        _reviews = list.map(_ReviewItem.fromJson).toList();
        _hasReviewed = hasReviewed;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedRating == 0 || _submitting) return;
    setState(() => _submitting = true);
    try {
      final auth = context.read<AuthProvider>();
      final token =
          auth.isAuthenticated ? await auth.getAccessToken() : null;
      final options = token != null
          ? Options(headers: {'Authorization': 'Bearer $token'})
          : null;
      final resp = await _dio.post(
        '/products/${widget.productId}/reviews',
        data: {
          if (token == null) 'author_name': 'Покупатель',
          'rating': _selectedRating,
          if (_textCtrl.text.trim().isNotEmpty) 'text': _textCtrl.text.trim(),
        },
        options: options,
      );
      final alreadyReviewed = resp.data is Map &&
          (resp.data as Map)['already_reviewed'] == true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('reviewed_${widget.productId}', true);
      if (!mounted) return;
      setState(() {
        _hasReviewed = true;
        _success = !alreadyReviewed;
        _submitting = false;
      });
      if (!alreadyReviewed) _load();
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось отправить отзыв')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canReview = auth.isAuthenticated;
    final visibleReviews = _showAll ? _reviews : _reviews.take(2).toList();
    final hasMore = _reviews.length > 2;

    final avgRating = _reviews.isEmpty
        ? 0.0
        : _reviews.map((r) => r.rating).reduce((a, b) => a + b) /
            _reviews.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Text(
              'Отзывы',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_reviews.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.purpleSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_reviews.length}',
                  style: const TextStyle(
                    color: AppColors.purple,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),

        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.purple,
                ),
              ),
            ),
          )
        else ...[
          // Rating summary
          if (_reviews.isNotEmpty) ...[
            const SizedBox(height: 14),
            _RatingSummary(avg: avgRating, count: _reviews.length),
            const SizedBox(height: 16),
          ] else ...[
            const SizedBox(height: 10),
            const Text(
              'Пока нет отзывов. Будьте первым!',
              style: TextStyle(color: AppColors.navyMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
          ],

          // Review list
          for (final r in visibleReviews) ...[
            _ReviewCard(review: r),
            const SizedBox(height: 10),
          ],
          if (hasMore && !_showAll)
            GestureDetector(
              onTap: () => setState(() => _showAll = true),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    const Text(
                      'Показать все отзывы',
                      style: TextStyle(
                        color: AppColors.purple,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.purple,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),

          // Review form
          if (canReview) ...[
            const Divider(color: AppColors.border),
            const SizedBox(height: 16),
            if (_hasReviewed)
              _success
                  ? _SuccessState()
                  : Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.purpleSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_outline_rounded,
                              color: AppColors.purple, size: 18),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Вы уже оставили отзыв',
                              style: TextStyle(
                                color: AppColors.purple,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
            else
              _ReviewForm(
                selectedRating: _selectedRating,
                textCtrl: _textCtrl,
                submitting: _submitting,
                onRatingChanged: (r) =>
                    setState(() => _selectedRating = r),
                onSubmit: _submit,
              ),
          ],
        ],
      ],
    );
  }
}

// ── Rating summary ─────────────────────────────────────────────────────────────

class _RatingSummary extends StatelessWidget {
  const _RatingSummary({required this.avg, required this.count});
  final double avg;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(
            avg.toStringAsFixed(1),
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Stars(rating: avg, size: 18),
              const SizedBox(height: 4),
              Text(
                '$count ${_pluralReview(count)}',
                style: const TextStyle(
                  color: AppColors.navyMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _pluralReview(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'отзыв';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
      return 'отзыва';
    }
    return 'отзывов';
  }
}

// ── Review card ────────────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final _ReviewItem review;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Stars(rating: review.rating.toDouble(), size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  review.authorName,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (review.isVerified)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Верифицирован',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          if (review.text != null && review.text!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.text!,
              style: const TextStyle(
                color: AppColors.navyMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            _formatDate(review.createdAt),
            style: const TextStyle(
              color: AppColors.navyMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) {
    const months = [
      '',
      'янв',
      'фев',
      'мар',
      'апр',
      'май',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек',
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }
}

// ── Review form ────────────────────────────────────────────────────────────────

class _ReviewForm extends StatelessWidget {
  const _ReviewForm({
    required this.selectedRating,
    required this.textCtrl,
    required this.submitting,
    required this.onRatingChanged,
    required this.onSubmit,
  });

  final int selectedRating;
  final TextEditingController textCtrl;
  final bool submitting;
  final ValueChanged<int> onRatingChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Оставить отзыв',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(5, (i) {
            final filled = selectedRating > i;
            return GestureDetector(
              onTap: () => onRatingChanged(i + 1),
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 36,
                  color: filled ? AppColors.yellow : AppColors.border,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: textCtrl,
          maxLines: 3,
          minLines: 2,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: 'Расскажите о товаре (необязательно)',
            hintStyle: const TextStyle(
              color: AppColors.navyMuted,
              fontSize: 13,
            ),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.purple, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: selectedRating > 0 && !submitting ? onSubmit : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Отправить отзыв'),
          ),
        ),
      ],
    );
  }
}

// ── Success state ──────────────────────────────────────────────────────────────

class _SuccessState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 20),
          SizedBox(width: 10),
          Flexible(
            child: Text(
              'Спасибо за отзыв!',
              style: TextStyle(
                color: AppColors.success,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Related products ───────────────────────────────────────────────────────────

class _RelatedProducts extends StatelessWidget {
  const _RelatedProducts({
    required this.products,
    required this.onTap,
    required this.provider,
  });

  final List<Product> products;
  final ValueChanged<Product> onTap;
  final MarketProvider provider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Похожие товары',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final p = products[i];
              final cartQty = provider.cartQuantityFor(p.id);
              return SizedBox(
                width: 150,
                child: ProductCard(
                  name: p.title,
                  price: p.price.round(),
                  regularPrice: p.originalPrice?.round(),
                  imageUrl: p.imageUrl.isNotEmpty ? p.imageUrl : null,
                  size: p.packageInfo.isNotEmpty ? p.packageInfo : null,
                  isInCart: cartQty > 0,
                  onTap: () => onTap(p),
                  onAddToCart: () => provider.addToCartWithQty(p, 1),
                ),
              );
            },
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
    required this.cartQty,
    required this.available,
    required this.onAddToCart,
    required this.onIncrement,
    required this.onDecrement,
  });

  final Product product;
  final int cartQty;
  final int available;
  final VoidCallback? onAddToCart;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.075),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(top: false, child: _buildContent()),
    );
  }

  Widget _buildContent() {
    if (!product.inStock) {
      return SizedBox(
        height: 52,
        width: double.infinity,
        child: FilledButton(
          onPressed: null,
          child: const Text('Нет в наличии'),
        ),
      );
    }
    if (cartQty > 0) {
      // Purple stepper
      return Container(
        height: 52,
        decoration: const BoxDecoration(
          color: AppColors.purple,
          borderRadius: AppRadii.buttonBorder,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _StepperBtn(
              icon: Icons.remove_rounded,
              onTap: onDecrement,
              forceLight: true,
            ),
            Text(
              '$cartQty',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            _StepperBtn(
              icon: Icons.add_rounded,
              onTap: onIncrement,
              forceLight: true,
            ),
          ],
        ),
      );
    }
    // Not in cart: price + button
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatMoney(product.price.round()),
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (product.originalPrice != null &&
                product.originalPrice! > product.price)
              Text(
                formatMoney(product.originalPrice!.round()),
                style: const TextStyle(
                  color: AppColors.navyMuted,
                  fontSize: 13,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: AppColors.navyMuted,
                ),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: 52,
            child: FilledButton(
              key: const Key('detail-add-to-cart'),
              onPressed: onAddToCart,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_cart_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    available == 0 ? 'Максимум' : 'В корзину',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Stepper button ─────────────────────────────────────────────────────────────

class _StepperBtn extends StatelessWidget {
  const _StepperBtn({
    required this.icon,
    required this.onTap,
    this.forceLight = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool forceLight;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final Color iconColor;
    if (forceLight) {
      iconColor = enabled
          ? Colors.white
          : Colors.white.withValues(alpha: 0.4);
    } else {
      iconColor = enabled ? AppColors.navy : AppColors.border;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        height: 50,
        child: Icon(icon, size: 20, color: iconColor),
      ),
    );
  }
}

// ── Stars widget ───────────────────────────────────────────────────────────────

class _Stars extends StatelessWidget {
  const _Stars({required this.rating, this.size = 16});
  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = rating >= i + 1;
        final half = !filled && rating >= i + 0.5;
        return Icon(
          filled
              ? Icons.star_rounded
              : half
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded,
          size: size,
          color: AppColors.yellow,
        );
      }),
    );
  }
}

// ── Skeleton ───────────────────────────────────────────────────────────────────

class _ProductDetailSkeleton extends StatelessWidget {
  const _ProductDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          // Gallery skeleton
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            child: Skeleton(height: 340, width: double.infinity, radius: 0),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Skeleton.rect(width: 80, height: 12),
                  ),
                ),
                const SizedBox(height: 8),
                Skeleton.rect(height: 22),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Skeleton.rect(width: 200, height: 22),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Skeleton.rect(width: 160, height: 16),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Skeleton.rect(width: 120, height: 28),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Skeleton.rect(width: 180, height: 32),
                  ),
                ),
                const SizedBox(height: 28),
                Skeleton.rect(height: 56),
                const SizedBox(height: 28),
                Row(
                  children: [
                    for (int i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: Skeleton.rect(height: 80)),
                    ],
                  ],
                ),
                const SizedBox(height: 28),
                Skeleton.rect(height: 56),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Skeleton.rect(width: 100, height: 16),
                  ),
                ),
                const SizedBox(height: 10),
                Skeleton.rect(height: 14),
                const SizedBox(height: 6),
                Skeleton.rect(height: 14),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Skeleton.rect(width: 240, height: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
