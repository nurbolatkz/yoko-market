import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/banner_item.dart';
import '../models/product.dart';
import '../providers/market_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/product_image.dart';
import 'product_detail_screen.dart';
import 'promotion_detail_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    super.key,
    required this.onCategorySelected,
    required this.onSearchSubmitted,
    required this.onCartTapped,
  });

  final ValueChanged<String> onCategorySelected;
  final VoidCallback onSearchSubmitted;
  final VoidCallback onCartTapped;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MarketProvider>();
    final cartCount = provider.cartItemCount;
    final cartTotal = provider.cartTotalAmount;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            CustomScrollView(
              key: const Key('home-scroll'),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  sliver: SliverList.list(
                    children: [
                      const _Header(),
                      const SizedBox(height: 12),
                      _SearchBar(
                        controller: _searchCtrl,
                        onSubmitted: (value) {
                          provider.setSearchQuery(value);
                          provider.loadProducts();
                          widget.onSearchSubmitted();
                        },
                      ),
                      const SizedBox(height: 18),
                      if (provider.banners.isNotEmpty) ...[
                        _BannerCarousel(banners: provider.banners),
                        const SizedBox(height: 24),
                      ],
                      _Categories(
                        categories: provider.categories,
                        onSelected: widget.onCategorySelected,
                        onSeeAll: () => widget.onCategorySelected('All'),
                      ),
                      if (provider.featuredProducts.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        _SectionHeader(
                          title: 'Лучшие предложения',
                          onSeeAll: () => widget.onCategorySelected('All'),
                        ),
                        const SizedBox(height: 14),
                        _HorizontalProductRow(
                          products: provider.featuredProducts,
                          provider: provider,
                        ),
                      ],
                      if (provider.lastSeenProducts.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        const _SectionHeader(title: 'Недавно просмотренные'),
                        const SizedBox(height: 14),
                        _HorizontalProductRow(
                          products: provider.lastSeenProducts,
                          provider: provider,
                        ),
                      ],
                      const SizedBox(height: 28),
                      _SectionHeader(
                        title: 'Популярные товары',
                        onSeeAll: () => widget.onCategorySelected('All'),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
                _ProductGrid(provider: provider),
                SliverToBoxAdapter(
                  child: SizedBox(height: cartCount > 0 ? 120 : 96),
                ),
              ],
            ),
            if (cartCount > 0)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _CartPanel(
                  itemCount: cartCount,
                  total: cartTotal,
                  onTap: widget.onCartTapped,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/logo.png',
          height: 28,
          fit: BoxFit.fitHeight,
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 13,
                  color: AppColors.purple,
                ),
                const SizedBox(width: 3),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 60),
                  child: const Text(
                    'Алматы',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: AppColors.navyMuted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onSubmitted});

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('home-search'),
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: 'Поиск товаров',
        hintStyle: const TextStyle(color: AppColors.navyMuted, fontSize: 14),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.navyMuted,
          size: 20,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 11,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.purple, width: 1.5),
        ),
      ),
    );
  }
}

// ── Banner carousel ───────────────────────────────────────────────────────

class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({required this.banners});

  final List<BannerItem> banners;

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final PageController _ctrl = PageController();
  int _current = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = (constraints.maxWidth / 2.1).clamp(130.0, 180.0);
        return Column(
          children: [
            SizedBox(
              height: height,
              child: PageView.builder(
                controller: _ctrl,
                itemCount: widget.banners.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (context, index) => Padding(
                  padding: EdgeInsets.only(
                    right: index < widget.banners.length - 1 ? 10 : 0,
                  ),
                  child: _BannerCard(
                    banner: widget.banners[index],
                    height: height,
                  ),
                ),
              ),
            ),
            if (widget.banners.length > 1) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.banners.length, (i) {
                  final active = i == _current;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: active ? 18 : 6,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    decoration: BoxDecoration(
                      color: active ? AppColors.purple : AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner, required this.height});

  final BannerItem banner;
  final double height;

  void _onTap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PromotionDetailScreen(bannerId: banner.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = banner.textDark ? AppColors.navy : Colors.white;
    final subColor = banner.textDark
        ? AppColors.navyMuted
        : Colors.white.withAlpha(200);
    final eyebrowBg = banner.textDark
        ? Colors.white.withAlpha(180)
        : Colors.white.withAlpha(46);

    final hasPrice =
        banner.originalPrice != null && banner.discountPrice != null;
    final discPct = hasPrice
        ? (100 - (banner.discountPrice! / banner.originalPrice!) * 100).round()
        : null;
    final discLabel =
        banner.discountBadge ?? (discPct != null ? '−$discPct%' : null);

    return GestureDetector(
      onTap: () => _onTap(context),
      child: ClipRRect(
        borderRadius: AppRadii.cardBorder,
        child: Container(
          height: height,
          decoration: _parseBackground(banner.bgColor),
          child: Stack(
            children: [
              if (banner.imageUrl != null)
                Positioned.fill(
                  child: Image.network(
                    banner.imageUrl!,
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                    errorBuilder: (_, e, s) => const SizedBox.shrink(),
                  ),
                ),
              if (banner.imageUrl != null)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withAlpha(130),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.65],
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (banner.badge != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: eyebrowBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          banner.badge!,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      banner.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (banner.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        banner.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: subColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (hasPrice) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${banner.discountPrice!} ₸',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${banner.originalPrice!} ₸',
                            style: TextStyle(
                              color: textColor.withAlpha(150),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: textColor.withAlpha(150),
                            ),
                          ),
                          if (discLabel != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: eyebrowBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                discLabel,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _onTap(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.yellow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Купить',
                            style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ] else if (banner.isPromoOrGiveaway) ...[
                      Text(
                        banner.promoType == 'giveaway'
                            ? 'Подробнее о розыгрыше  →'
                            : 'Подробнее об акции  →',
                        style: TextStyle(
                          color: textColor.withAlpha(220),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

BoxDecoration _parseBackground(String bg) {
  if (bg.startsWith('linear-gradient')) {
    final colorRe = RegExp(r'(#[0-9a-fA-F]{6})\s+([\d.]+)%');
    final matches = colorRe.allMatches(bg).toList();
    if (matches.length >= 2) {
      final colors = matches
          .map((m) => Color(int.parse('0xFF${m.group(1)!.substring(1)}')))
          .toList();
      final stops =
          matches.map((m) => double.parse(m.group(2)!) / 100).toList();
      final anglePct = RegExp(r'(\d+)deg').firstMatch(bg);
      final angleDeg =
          anglePct != null ? double.parse(anglePct.group(1)!) : 135.0;
      final dx = _angleToDx(angleDeg);
      final dy = _angleToDy(angleDeg);
      return BoxDecoration(
        borderRadius: AppRadii.cardBorder,
        gradient: LinearGradient(
          begin: Alignment(-dx, -dy),
          end: Alignment(dx, dy),
          colors: colors,
          stops: stops,
        ),
      );
    }
  }
  try {
    final hex = bg.replaceFirst('#', '');
    final colorVal = int.parse('FF$hex', radix: 16);
    return BoxDecoration(
      borderRadius: AppRadii.cardBorder,
      color: Color(colorVal),
    );
  } catch (_) {
    return const BoxDecoration(
      borderRadius: AppRadii.cardBorder,
      color: Color(0xFF1D2E81),
    );
  }
}

double _angleToDx(double deg) {
  final r = (deg - 90) * 3.14159265 / 180;
  return r.isNaN ? 0.0 : max(-1.0, _cos(r)).clamp(-1.0, 1.0);
}

double _angleToDy(double deg) {
  final r = (deg - 90) * 3.14159265 / 180;
  return r.isNaN ? 1.0 : _sin(r).clamp(-1.0, 1.0);
}

double _cos(double r) => _sin(r + 1.5707963);

double _sin(double r) {
  var x = r % (2 * 3.14159265);
  if (x > 3.14159265) x -= 2 * 3.14159265;
  if (x < -3.14159265) x += 2 * 3.14159265;
  final sign = x >= 0 ? 1.0 : -1.0;
  x = x.abs();
  return sign *
      (16 * x * (3.14159265 - x)) /
      (5 * 3.14159265 * 3.14159265 - 4 * x * (3.14159265 - x));
}

// ── Categories ────────────────────────────────────────────────────────────

class _Categories extends StatelessWidget {
  const _Categories({
    required this.categories,
    required this.onSelected,
    required this.onSeeAll,
  });

  final List<String> categories;
  final ValueChanged<String> onSelected;
  final VoidCallback onSeeAll;

  static const _pastelColors = [
    Color(0xFFDCEEFF),
    Color(0xFFFFF3DC),
    Color(0xFFDCFFEE),
    Color(0xFFFFDCEC),
    Color(0xFFEEDCFF),
    Color(0xFFDCFFF5),
  ];

  static const _iconColors = [
    Color(0xFF3B9BE8),
    Color(0xFFE8A020),
    Color(0xFF20B060),
    Color(0xFFE82070),
    Color(0xFF8B40E8),
    Color(0xFF20B0A0),
  ];

  static const _icons = {
    'подгузник': Icons.baby_changing_station_rounded,
    'пелёнк': Icons.layers_outlined,
    'косметик': Icons.spa_outlined,
    'химия': Icons.cleaning_services_outlined,
    'салфетк': Icons.water_drop_outlined,
    'питани': Icons.local_dining_outlined,
    'одежда': Icons.checkroom_outlined,
    'игрушк': Icons.toys_outlined,
    'бумаг': Icons.receipt_long_outlined,
    'палочк': Icons.medical_services_outlined,
  };

  static IconData _iconFor(String name) {
    final lower = name.toLowerCase();
    for (final entry in _icons.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return Icons.category_outlined;
  }

  Widget _buildItem(int i, String name) {
    final bgColor = _pastelColors[i % _pastelColors.length];
    final iconColor = _iconColors[i % _iconColors.length];
    return Expanded(
      child: InkWell(
        key: Key('home-category-$name'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => onSelected(name),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(_iconFor(name), color: iconColor, size: 26),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 30,
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 10,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = categories.where((c) => c != 'All').take(8).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    // Split into rows of 4
    final rows = <Widget>[];
    for (var start = 0; start < items.length; start += 4) {
      final rowItems = items.sublist(start, (start + 4).clamp(0, items.length));
      // Pad to 4 with invisible fillers so items stay same width
      final rowWidgets = [
        ...rowItems.asMap().entries.map((e) => _buildItem(start + e.key, e.value)),
        ...List.generate(4 - rowItems.length, (_) => const Expanded(child: SizedBox())),
      ];
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 12));
      rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: rowWidgets));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Категории', onSeeAll: onSeeAll),
        const SizedBox(height: 12),
        ...rows,
      ],
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (onSeeAll != null) ...[
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onSeeAll,
            child: const Text(
              'Все  →',
              style: TextStyle(
                color: AppColors.purple,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Product grid ──────────────────────────────────────────────────────────

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.provider});

  final MarketProvider provider;

  @override
  Widget build(BuildContext context) {
    final products = provider.filteredProducts.take(4).toList();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid.builder(
        itemCount: products.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.62,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemBuilder: (context, index) {
          final product = products[index];
          final cartQty = provider.cartQuantityFor(product.id);
          final canAdd = product.inStock && cartQty < product.stockQuantity;
          final hasDiscount = product.originalPrice != null &&
              product.originalPrice! > product.price;
          final discPct = hasDiscount
              ? ((1 - product.price / product.originalPrice!) * 100).round()
              : 0;

          return InkWell(
            borderRadius: AppRadii.cardBorder,
            onTap: () {
              context.read<MarketProvider>().recordView(product);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(product: product),
                ),
              );
            },
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
                  // Photo with optional discount badge
                  Expanded(
                    flex: 5,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: double.infinity,
                            child: ProductImage(
                              key: Key('home-product-image-${product.id}'),
                              imageUrl: product.imageUrl,
                            ),
                          ),
                        ),
                        if (hasDiscount)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF4444),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '-$discPct%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Prices
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${product.price.toStringAsFixed(0)} ₸',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.purple,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (hasDiscount) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${product.originalPrice!.toStringAsFixed(0)} ₸',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.navyMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Name
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Rating
                  if (product.rating > 0)
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: AppColors.yellow,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          product.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: AppColors.navyMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  const Spacer(),
                  // Stepper or add button
                  Align(
                    alignment: Alignment.centerRight,
                    child: cartQty > 0
                        ? _Stepper(
                            qty: cartQty,
                            canIncrement: canAdd,
                            onDecrement: () {
                              if (cartQty > 1) {
                                provider.updateQuantity(
                                  product.id,
                                  cartQty - 1,
                                );
                              } else {
                                provider.removeFromCart(product.id);
                              }
                            },
                            onIncrement: canAdd
                                ? () => provider.addToCart(product)
                                : null,
                          )
                        : _AddButton(
                            canAdd: canAdd,
                            onTap: canAdd
                                ? () => provider.addToCart(product)
                                : null,
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Horizontal product row (Best sellers / Last seen) ─────────────────────

class _HorizontalProductRow extends StatelessWidget {
  const _HorizontalProductRow({
    required this.products,
    required this.provider,
  });

  final List<Product> products;
  final MarketProvider provider;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final product = products[index];
          final cartQty = provider.cartQuantityFor(product.id);
          final canAdd = product.inStock && cartQty < product.stockQuantity;
          final hasDiscount = product.originalPrice != null &&
              product.originalPrice! > product.price;

          return GestureDetector(
            onTap: () {
              provider.recordView(product);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(product: product),
                ),
              );
            },
            child: Container(
              width: 140,
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
                  Expanded(
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox.expand(
                            child: ProductImage(imageUrl: product.imageUrl),
                          ),
                        ),
                        if (hasDiscount)
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.yellow,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '−${((1 - product.price / product.originalPrice!) * 100).round()}%',
                                style: const TextStyle(
                                  color: AppColors.navy,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${product.price.toInt()} ₸',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.purple,
                          ),
                        ),
                      ),
                      if (canAdd)
                        GestureDetector(
                          onTap: () => provider.addToCart(product),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              color: AppColors.purple,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Stepper ───────────────────────────────────────────────────────────────

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.qty,
    required this.canIncrement,
    required this.onDecrement,
    this.onIncrement,
  });

  final int qty;
  final bool canIncrement;
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
          _StepBtn(
            icon: Icons.remove,
            onTap: onDecrement,
            active: true,
          ),
          SizedBox(
            width: 26,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.purple,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _StepBtn(
            icon: Icons.add,
            onTap: onIncrement,
            active: canIncrement,
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap, required this.active});

  final IconData icon;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: active ? onTap : null,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Icon(
          icon,
          size: 16,
          color: active ? AppColors.purple : AppColors.border,
        ),
      ),
    );
  }
}

// ── Add button ────────────────────────────────────────────────────────────

class _AddButton extends StatefulWidget {
  const _AddButton({required this.canAdd, this.onTap});

  final bool canAdd;
  final VoidCallback? onTap;

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: (_pressed && widget.canAdd) ? 0.86 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeInOut,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: widget.canAdd ? AppColors.yellow : AppColors.border,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            Icons.add,
            size: 17,
            color: widget.canAdd ? AppColors.navy : AppColors.navyMuted,
          ),
        ),
      ),
    );
  }
}

// ── Cart panel ────────────────────────────────────────────────────────────

class _CartPanel extends StatelessWidget {
  const _CartPanel({
    required this.itemCount,
    required this.total,
    required this.onTap,
  });

  final int itemCount;
  final double total;
  final VoidCallback onTap;

  String _itemWord(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'товар';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
      return 'товара';
    }
    return 'товаров';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.purple,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.purple.withAlpha(80),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.shopping_cart_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Корзина',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Container(width: 1, height: 14, color: Colors.white38),
            const SizedBox(width: 8),
            Text(
              '$itemCount ${_itemWord(itemCount)}',
              style: TextStyle(
                color: Colors.white.withAlpha(200),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              '${total.toStringAsFixed(0)} ₸',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 13,
            ),
          ],
        ),
      ),
    );
  }
}
