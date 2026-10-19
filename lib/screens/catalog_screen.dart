import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/banner_item.dart';
import '../providers/market_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/product_image.dart';
import 'product_detail_screen.dart';
import 'promotion_detail_screen.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key, required this.onCategorySelected});

  final ValueChanged<String> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MarketProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          key: const Key('home-scroll'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              sliver: SliverList.list(
                children: [
                  const _Header(),
                  const SizedBox(height: 18),
                  if (provider.banners.isNotEmpty) ...[
                    _BannerCarousel(banners: provider.banners),
                    const SizedBox(height: 24),
                  ],
                  _Categories(
                    categories: provider.categories,
                    onSelected: onCategorySelected,
                  ),
                  const SizedBox(height: 28),
                  const _SectionHeader(title: 'Популярные товары'),
                  const SizedBox(height: 14),
                ],
              ),
            ),
            _ProductGrid(provider: provider),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
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
        // Logo №1: purple Y on yellow circle
        SizedBox(
          width: 32,
          height: 32,
          child: Stack(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.yellow,
                  shape: BoxShape.circle,
                ),
              ),
              const Center(
                child: Text(
                  'Y',
                  style: TextStyle(
                    color: AppColors.purple,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // App name — Flexible so it truncates before overflowing on narrow screens
        Flexible(
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: const TextSpan(
              style: TextStyle(fontFamily: 'Roboto', letterSpacing: -0.3),
              children: [
                TextSpan(
                  text: 'Yo',
                  style: TextStyle(
                    color: AppColors.purple,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(
                  text: ' Market',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // City selector placeholder — constrained so Ahem test-font can't overflow
        GestureDetector(
          onTap: () {},
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 13,
                color: AppColors.purple,
              ),
              const SizedBox(width: 2),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 50),
                child: const Text(
                  'Алматы',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.navyMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 13,
                color: AppColors.navyMuted,
              ),
            ],
          ),
        ),
      ],
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
        final height = (constraints.maxWidth / 2.2).clamp(130.0, 175.0);
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
    if (banner.isPromoOrGiveaway) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PromotionDetailScreen(bannerId: banner.id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor =
        banner.textDark ? AppColors.navy : Colors.white;
    final subColor = banner.textDark
        ? AppColors.navyMuted
        : Colors.white.withAlpha(200);
    final eyebrowBg = banner.textDark
        ? Colors.white.withAlpha(180)
        : Colors.white.withAlpha(46);

    final hasPrice =
        banner.originalPrice != null && banner.discountPrice != null;
    final discPct = hasPrice
        ? (100 - (banner.discountPrice! / banner.originalPrice!) * 100)
            .round()
        : null;
    final discLabel = banner.discountBadge ??
        (discPct != null ? '−$discPct%' : null);

    return GestureDetector(
      onTap: banner.isPromoOrGiveaway ? () => _onTap(context) : null,
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
              // Left gradient so text is readable over image
              if (banner.imageUrl != null)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withAlpha(140),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.7],
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (banner.badge != null)
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
                    if (banner.badge != null) const SizedBox(height: 6),
                    Text(
                      banner.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
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
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (hasPrice) ...[
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${banner.discountPrice!} ₸',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${banner.originalPrice!} ₸',
                            style: TextStyle(
                              color: textColor.withAlpha(160),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.lineThrough,
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
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ] else if (banner.isPromoOrGiveaway) ...[
                      const Spacer(),
                      Row(
                        children: [
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
    // Parse CSS linear-gradient into Flutter LinearGradient.
    // Supports the pattern: linear-gradient(Xdeg, #COLOR stop%, ...)
    final colorRe = RegExp(r'(#[0-9a-fA-F]{6})\s+([\d.]+)%');
    final matches = colorRe.allMatches(bg).toList();
    if (matches.length >= 2) {
      final colors = matches
          .map((m) => Color(int.parse('0xFF${m.group(1)!.substring(1)}')))
          .toList();
      final stops = matches
          .map((m) => double.parse(m.group(2)!) / 100)
          .toList();
      // Extract angle: "linear-gradient(135deg, ...)" → 135
      final anglePct = RegExp(r'(\d+)deg').firstMatch(bg);
      final angleDeg = anglePct != null ? double.parse(anglePct.group(1)!) : 135.0;
      final radians = angleDeg * 3.14159265 / 180;
      final dx = radians.isNaN ? 0.0 : _angleToDx(angleDeg);
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
  // Solid color
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
  return r.isNaN ? 0.0 : max(-1.0, r.isNaN ? 0.0 : _cos(r)).clamp(-1.0, 1.0);
}

double _angleToDy(double deg) {
  final r = (deg - 90) * 3.14159265 / 180;
  return r.isNaN ? 1.0 : _sin(r).clamp(-1.0, 1.0);
}

double _cos(double r) {
  // cos approximation via identity sin(r+π/2)
  return _sin(r + 1.5707963);
}

double _sin(double r) {
  // Reduce to [-π,π]
  var x = r % (2 * 3.14159265);
  if (x > 3.14159265) x -= 2 * 3.14159265;
  if (x < -3.14159265) x += 2 * 3.14159265;
  // Bhaskara I approximation good enough for banner gradients
  final sign = x >= 0 ? 1.0 : -1.0;
  x = x.abs();
  return sign * (16 * x * (3.14159265 - x)) / (5 * 3.14159265 * 3.14159265 - 4 * x * (3.14159265 - x));
}

// ── Categories ────────────────────────────────────────────────────────────

class _Categories extends StatelessWidget {
  const _Categories({
    required this.categories,
    required this.onSelected,
  });

  final List<String> categories;
  final ValueChanged<String> onSelected;

  // Fallback icons keyed by partial category name (case-insensitive)
  static const _icons = {
    'подгузник': Icons.baby_changing_station_rounded,
    'косметик': Icons.spa_outlined,
    'химия': Icons.cleaning_services_outlined,
    'салфетк': Icons.layers_outlined,
    'питание': Icons.local_dining_outlined,
    'одежда': Icons.checkroom_outlined,
    'игрушк': Icons.toys_outlined,
  };

  static IconData _iconFor(String name) {
    final lower = name.toLowerCase();
    for (final entry in _icons.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return Icons.category_outlined;
  }

  @override
  Widget build(BuildContext context) {
    // Show at most 5 categories; skip the 'All' sentinel
    final items = categories.where((c) => c != 'All').take(5).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Категории', showAll: false),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items
              .map(
                (name) => Expanded(
                  child: InkWell(
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
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x14000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _iconFor(name),
                                color: AppColors.purple,
                                size: 26,
                              ),
                            ),
                          ),
                          const SizedBox(height: 7),
                          SizedBox(
                            height: 31,
                            child: Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontSize: 10.5,
                                height: 1.2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.showAll = true});

  final String title;
  final bool showAll;

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
        if (showAll) ...[
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {},
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
          childAspectRatio: .70,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemBuilder: (context, index) {
          final product = products[index];
          final cartQty = provider.cartQuantityFor(product.id);
          final canAdd = product.inStock && cartQty < product.stockQuantity;

          return InkWell(
            borderRadius: AppRadii.cardBorder,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(product: product),
              ),
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
                  // Photo
                  Expanded(
                    flex: 5,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ProductImage(
                          key: Key('home-product-image-${product.id}'),
                          imageUrl: product.imageUrl,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  // Price
                  Text(
                    '${product.price.toStringAsFixed(0)} ₸',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.purple,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Name
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  // Size / stock line
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          product.packageInfo.isNotEmpty
                              ? product.packageInfo
                              : (!product.inStock
                                  ? 'Нет в наличии'
                                  : canAdd
                                      ? 'В наличии'
                                      : 'Максимум в корзине'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: !product.inStock
                                ? Colors.red.shade600
                                : product.packageInfo.isNotEmpty
                                    ? AppColors.navyMuted
                                    : canAdd
                                        ? const Color(0xFF1E7D47)
                                        : AppColors.navyMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // Add to cart button
                      _AddButton(
                        canAdd: canAdd,
                        onTap: canAdd
                            ? () => provider.addToCart(product)
                            : null,
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

// ── Add button with scale feedback ───────────────────────────────────────

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
