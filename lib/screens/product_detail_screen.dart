import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/market_provider.dart';
import '../providers/wishlist_provider.dart';
import '../services/catalog_api.dart';
import '../theme/app_theme.dart';
import '../utils/dio_error.dart';
import '../widgets/product_image.dart';
import '../widgets/ui/error_state.dart';

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
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
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
  int _qty = 1;
  int _galleryPage = 0;
  final _pageCtrl = PageController();
  bool _detailLoading = true;
  String? _detailError;

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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _detailLoading = false;
        _detailError = networkErrorMessage(e);
      });
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
        reviewCount: _baseProduct.reviewCount,
      );

  bool get _isCurrentVariant {
    if (_variants.isEmpty) return false;
    return _variants.every((v) => v.id != _activeProduct.id);
  }

  @override
  Widget build(BuildContext context) {
    if (_detailLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_detailError != null) {
      return Scaffold(
        appBar: AppBar(),
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
      backgroundColor: AppColors.homeBackground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.homeBackground,
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
                    isFav
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFav ? AppColors.purple : Colors.black87,
                    size: 22,
                  ),
                ),
                onPressed: () async {
                  final token =
                      await context.read<AuthProvider>().getAccessToken();
                  if (!context.mounted) return;
                  context
                      .read<WishlistProvider>()
                      .toggle(_activeProduct, accessToken: token);
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PriceRow(product: _activeProduct),
                    const SizedBox(height: 10),
                    _NameRow(product: _activeProduct),
                    const SizedBox(height: 10),
                    _RatingStockRow(product: _activeProduct),
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
                      _DescriptionSection(
                          text: _activeProduct.description),
                    ],
                    const SizedBox(height: 28),
                    _ReviewsSection(productId: _activeProduct.id),
                    const SizedBox(height: 110),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _BottomBar(
        product: _activeProduct,
        qty: _qty,
        available: available,
        onIncrement:
            _activeProduct.inStock && available > 0 && _qty < available
                ? () => setState(() => _qty++)
                : null,
        onDecrement: _qty > 1 ? () => setState(() => _qty--) : null,
        onAddToCart:
            _activeProduct.inStock && available > 0 && _qty <= available
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
        atMax: _activeProduct.inStock &&
            (available == 0 || _qty > available),
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
    final urls = imageUrls.isNotEmpty
        ? imageUrls
        : (fallbackUrl.isNotEmpty ? [fallbackUrl] : <String>[]);
    if (urls.isEmpty) {
      return Container(
        color: AppColors.homeBackground,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined,
            size: 64, color: AppColors.navyMuted),
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
    final discountPct = hasSale
        ? ((product.originalPrice! - product.price) /
                product.originalPrice! *
                100)
            .round()
        : 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F9EE),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '-$discountPct%',
              style: const TextStyle(
                color: Color(0xFF1B7F5E),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
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

// ── Rating + stock row ─────────────────────────────────────────────────────────

class _RatingStockRow extends StatelessWidget {
  const _RatingStockRow({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final inStock = product.inStock;
    return Row(
      children: [
        // Stars
        _Stars(rating: product.rating, size: 15),
        const SizedBox(width: 6),
        if (product.reviewCount > 0) ...[
          Text(
            product.rating.toStringAsFixed(1),
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '(${product.reviewCount})',
            style: const TextStyle(color: AppColors.navyMuted, fontSize: 13),
          ),
          const SizedBox(width: 12),
          Container(
            width: 1,
            height: 14,
            color: AppColors.border,
          ),
          const SizedBox(width: 12),
        ],
        Icon(
          inStock
              ? Icons.check_circle_outline_rounded
              : Icons.cancel_outlined,
          size: 15,
          color: inStock
              ? const Color(0xFF23804A)
              : Colors.red.shade700,
        ),
        const SizedBox(width: 5),
        Text(
          inStock
              ? 'В наличии: ${product.stockQuantity} шт.'
              : 'Нет в наличии',
          style: TextStyle(
            color: inStock
                ? const Color(0xFF23804A)
                : Colors.red.shade700,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Stars widget (display) ─────────────────────────────────────────────────────

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
          color: const Color(0xFFFBBC04),
        );
      }),
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
    // Hide the base chip when it's ONE and there are other variants
    final showBase = !(variants.isNotEmpty &&
        baseProduct.packageInfo.isEmpty);

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
              Text(
                '— выбран: $_selectedLabel',
                style: const TextStyle(
                  color: AppColors.purple,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
                price: v.price,
                isSelected: activeId == v.id,
                inStock: v.inStock,
                onTap: activeId == v.id ? null : () => onSelect(v),
              ),
          ],
        ),
      ],
    );
  }

  String get _selectedLabel {
    for (final v in variants) {
      if (v.id == activeId) return v.size != 'ONE' ? v.size : 'ONE';
    }
    return baseProduct.packageInfo.isNotEmpty ? baseProduct.packageInfo : 'ONE';
  }
}

class _SizeChip extends StatelessWidget {
  const _SizeChip({
    required this.label,
    required this.price,
    required this.isSelected,
    required this.inStock,
    required this.onTap,
  });

  final String label;
  final double price;
  final bool isSelected;
  final bool inStock;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: inStock ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                decoration:
                    inStock ? null : TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${price.toStringAsFixed(0)} ₸',
              style: TextStyle(
                color: isSelected
                    ? Colors.white.withValues(alpha: .85)
                    : AppColors.navyMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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

// ── Description section (expandable) ──────────────────────────────────────────

class _DescriptionSection extends StatefulWidget {
  const _DescriptionSection({required this.text});
  final String text;

  @override
  State<_DescriptionSection> createState() => _DescriptionSectionState();
}

class _DescriptionSectionState extends State<_DescriptionSection> {
  bool _expanded = false;
  static const _collapsedMaxLines = 4;

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
        // Only show toggle if text is long enough to collapse
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
                _expanded ? 'Свернуть' : 'Показать полностью',
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
      final resp = await _dio.get('/products/${widget.productId}/reviews');
      final list = (resp.data as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
      final prefs = await SharedPreferences.getInstance();
      final hasReviewed = prefs.getBool('reviewed_${widget.productId}') ?? false;
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
      final token = auth.isAuthenticated ? await auth.getAccessToken() : null;
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
    final visibleReviews =
        _showAll ? _reviews : _reviews.take(3).toList();
    final hasMore = _reviews.length > 3;

    // Compute average from loaded reviews
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                          Text(
                            'Вы уже оставили отзыв',
                            style: TextStyle(
                              color: AppColors.purple,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
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

  String _pluralReview(int n) {
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
                    color: const Color(0xFFE8F9EE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Верифицирован',
                    style: TextStyle(
                      color: Color(0xFF1B7F5E),
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

  String _formatDate(DateTime d) {
    const months = [
      '', 'янв', 'фев', 'мар', 'апр', 'май', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
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
                  color: filled
                      ? const Color(0xFFFBBC04)
                      : AppColors.border,
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

// ── Success state after review ─────────────────────────────────────────────────

class _SuccessState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F9EE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_rounded,
              color: Color(0xFF1B7F5E), size: 20),
          SizedBox(width: 10),
          Text(
            'Спасибо за отзыв!',
            style: TextStyle(
              color: Color(0xFF1B7F5E),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
    final canAdd = onAddToCart != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 12, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Qty stepper
            Container(
              height: 50,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StepperBtn(
                    icon: Icons.remove_rounded,
                    onTap: onDecrement,
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '$qty',
                      key: const Key('detail-qty-label'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  _StepperBtn(
                    icon: Icons.add_rounded,
                    onTap: onIncrement,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Add to cart button
            Expanded(
              child: SizedBox(
                height: 50,
                child: FilledButton(
                  key: const Key('detail-add-to-cart'),
                  onPressed: onAddToCart,
                  style: FilledButton.styleFrom(
                    backgroundColor: canAdd
                        ? AppColors.purple
                        : AppColors.purpleDisabled,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shopping_cart_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        product.inStock
                            ? (atMax ? 'Максимум' : 'В корзину')
                            : 'Нет в наличии',
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
        ),
      ),
    );
  }
}

class _StepperBtn extends StatelessWidget {
  const _StepperBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        height: 50,
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppColors.navy : AppColors.border,
        ),
      ),
    );
  }
}
