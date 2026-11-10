import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/banner_item.dart';
import '../models/product.dart';
import '../models/product_category.dart';
import '../providers/auth_provider.dart';
import '../providers/market_provider.dart';
import '../providers/wishlist_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/product_image.dart';
import '../widgets/ui/error_state.dart';
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

    final isInitialLoad =
        provider.catalogLoading && provider.categories.isEmpty;
    final hasError = !provider.catalogLoading &&
        provider.catalogError != null &&
        provider.categories.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.homeBackground,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            if (isInitialLoad)
              _HomeSkeleton(cartCount: cartCount)
            else if (hasError)
              Center(
                child: ErrorState(
                  message: provider.catalogError,
                  onRetry: () => provider.retryAll(),
                ),
              )
            else
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
                        if (provider.bannersLoading)
                          const _SkeletonBox(height: 160, radius: 16)
                        else if (provider.banners.isNotEmpty) ...[
                          _BannerCarousel(banners: provider.banners),
                          const SizedBox(height: 24),
                        ],
                        _Categories(
                          categories: provider.homeCategoryObjects,
                          onSelected: widget.onCategorySelected,
                          onSeeAll: () => widget.onCategorySelected('All'),
                        ),
                        if (provider.featuredLoading) ...[
                          const SizedBox(height: 28),
                          const _SkeletonBox(height: 18, width: 160, radius: 6),
                          const SizedBox(height: 14),
                          const _SkeletonHorizontalRow(),
                        ] else if (provider.featuredProducts.isNotEmpty) ...[
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
                        if (provider.bestSellersLoading) ...[
                          const SizedBox(height: 28),
                          const _SkeletonBox(height: 18, width: 140, radius: 6),
                          const SizedBox(height: 14),
                          const _SkeletonHorizontalRow(),
                        ] else if (provider.bestSellerProducts.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          _SectionHeader(
                            title: 'Хиты продаж',
                            onSeeAll: () => widget.onCategorySelected('All'),
                          ),
                          const SizedBox(height: 14),
                          _HorizontalProductRow(
                            products: provider.bestSellerProducts,
                            provider: provider,
                          ),
                        ],
                        if (provider.newArrivalsLoading) ...[
                          const SizedBox(height: 28),
                          const _SkeletonBox(height: 18, width: 110, radius: 6),
                          const SizedBox(height: 14),
                          const _SkeletonHorizontalRow(),
                        ] else if (provider.newArrivalProducts.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          _SectionHeader(
                            title: 'Новинки',
                            onSeeAll: () => widget.onCategorySelected('All'),
                          ),
                          const SizedBox(height: 14),
                          _HorizontalProductRow(
                            products: provider.newArrivalProducts,
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
                  SliverToBoxAdapter(child: const SizedBox(height: 96)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton / Error states ──────────────────────────────────────────────────

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.height,
    this.width,
    this.radius = 12,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.lavenderMid,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _SkeletonHorizontalRow extends StatelessWidget {
  const _SkeletonHorizontalRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, _) =>
            const _SkeletonBox(height: 220, width: 140),
      ),
    );
  }
}

class _SkeletonProductGrid extends StatelessWidget {
  const _SkeletonProductGrid();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid.builder(
        itemCount: 4,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.62,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemBuilder: (_, _) =>
            const _SkeletonBox(height: double.infinity, radius: 16),
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton({required this.cartCount});

  final int cartCount;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          sliver: SliverList.list(
            children: [
              const _Header(),
              const SizedBox(height: 12),
              const _SkeletonBox(height: 48, radius: 14),
              const SizedBox(height: 18),
              const _SkeletonBox(height: 160, radius: 16),
              const SizedBox(height: 24),
              // Horizontal circle skeletons for category strip
              SizedBox(
                height: 86,
                child: Row(
                  children: List.generate(5, (i) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Column(
                      children: [
                        const _SkeletonBox(height: 56, width: 56, radius: 28),
                        const SizedBox(height: 6),
                        Container(
                          height: 10,
                          width: 46,
                          decoration: BoxDecoration(
                            color: AppColors.lavenderMid,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  )),
                ),
              ),
              const SizedBox(height: 28),
              const _SkeletonBox(height: 18, width: 160, radius: 6),
              const SizedBox(height: 14),
              const _SkeletonHorizontalRow(),
              const SizedBox(height: 28),
              const _SkeletonBox(height: 18, width: 180, radius: 6),
              const SizedBox(height: 14),
            ],
          ),
        ),
        const _SkeletonProductGrid(),
        SliverToBoxAdapter(
          child: SizedBox(height: cartCount > 0 ? 120 : 96),
        ),
      ],
    );
  }
}

// ── Network image with loading skeleton + tap-to-retry ───────────────────────

class _RetryImage extends StatefulWidget {
  const _RetryImage({
    required this.url,
    required this.fit,
    this.alignment = Alignment.center,
    this.cacheWidth = 400,
  });

  final String url;
  final BoxFit fit;
  final Alignment alignment;
  // Physical pixels for the in-memory decode cache. 400 is fine for
  // small product thumbnails; pass null or a larger value for banners.
  final int? cacheWidth;

  @override
  State<_RetryImage> createState() => _RetryImageState();
}

class _RetryImageState extends State<_RetryImage> {
  int _attempt = 0;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      widget.url,
      key: ValueKey('${widget.url}_$_attempt'),
      fit: widget.fit,
      alignment: widget.alignment,
      cacheWidth: widget.cacheWidth,
      loadingBuilder: (ctx, child, prog) {
        if (prog == null) return child;
        return const ColoredBox(color: AppColors.lavenderMid);
      },
      errorBuilder: (ctx, _, _) => GestureDetector(
        onTap: () => setState(() => _attempt++),
        child: Container(
          color: AppColors.lavenderDeep,
          alignment: Alignment.center,
          child: const Icon(
            Icons.refresh_rounded,
            color: AppColors.purple,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset('assets/images/logo.png', height: 36, fit: BoxFit.fitHeight),
        const Spacer(),
        GestureDetector(
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on_rounded, size: 14, color: AppColors.purple),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 72),
                  child: const Text(
                    'Алматы',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: AppColors.navyMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Search bar ─────────────────────────────────────────────────────────────────

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
        hintStyle:
            const TextStyle(color: AppColors.navyMuted, fontSize: 14),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.navyMuted,
          size: 20,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
          borderSide:
              const BorderSide(color: AppColors.purple, width: 1.5),
        ),
      ),
    );
  }
}

// ── Banner carousel ───────────────────────────────────────────────────────────

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
        // 2.4:1 aspect ratio — wider landscape for image banners.
        // Falls back to 160 px minimum so text-only banners don't collapse.
        final height =
            (constraints.maxWidth / 2.4).clamp(140.0, 190.0);
        return Column(
          children: [
            SizedBox(
              height: height,
              child: PageView.builder(
                controller: _ctrl,
                itemCount: widget.banners.length,
                onPageChanged: (i) =>
                    setState(() => _current = i),
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
                children:
                    List.generate(widget.banners.length, (i) {
                  final active = i == _current;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: active ? 18 : 6,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.purple
                          : AppColors.lavenderDeep,
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

  String _ctaLabel(BannerItem b) {
    if (b.actionLabel != null && b.actionLabel!.isNotEmpty) return b.actionLabel!;
    return switch (b.actionType) {
      'product' => 'Смотреть товар',
      'category' => 'Перейти в каталог',
      _ => 'Подробнее',
    };
  }

  @override
  Widget build(BuildContext context) {
    // Image-only banner: image carries its own design — no duplicate text overlay.
    // A CTA chip sits in the bottom-left corner so users know it's tappable.
    if (banner.imageUrl != null) {
      return GestureDetector(
        onTap: () => _onTap(context),
        child: ClipRRect(
          borderRadius: AppRadii.cardBorder,
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Near-white bg so letterboxing is clean
                Container(color: AppColors.homeBackground),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final physicalW =
                        (constraints.maxWidth *
                                MediaQuery.devicePixelRatioOf(context))
                            .ceil();
                    return _RetryImage(
                      url: banner.imageUrl!,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      cacheWidth: physicalW.clamp(800, 2048),
                    );
                  },
                ),
                // CTA chip bottom-left
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: GestureDetector(
                    onTap: () => _onTap(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(230),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _ctaLabel(banner),
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.navy),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Text-only banner: title / subtitle / price on gradient background.
    final textColor =
        banner.textDark ? AppColors.navy : Colors.white;
    final subColor = banner.textDark
        ? AppColors.navyMuted
        : Colors.white.withAlpha(200);
    final eyebrowBg = banner.textDark
        ? Colors.white.withAlpha(180)
        : Colors.white.withAlpha(46);

    final hasPrice = banner.originalPrice != null &&
        banner.discountPrice != null;
    final discPct = hasPrice
        ? (100 -
                (banner.discountPrice! / banner.originalPrice!) * 100)
            .round()
        : null;
    final discLabel = banner.discountBadge ??
        (discPct != null ? '−$discPct%' : null);

    return GestureDetector(
      onTap: () => _onTap(context),
      child: ClipRRect(
        borderRadius: AppRadii.cardBorder,
        child: Container(
          height: height,
          decoration: _parseBackground(banner.bgColor),
          child: Padding(
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
          .map((m) =>
              Color(int.parse('0xFF${m.group(1)!.substring(1)}')))
          .toList();
      final stops = matches
          .map((m) => double.parse(m.group(2)!) / 100)
          .toList();
      final anglePct = RegExp(r'(\d+)deg').firstMatch(bg);
      final angleDeg = anglePct != null
          ? double.parse(anglePct.group(1)!)
          : 135.0;
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

// ── Categories ─────────────────────────────────────────────────────────────────

class _Categories extends StatelessWidget {
  const _Categories({
    required this.categories,
    required this.onSelected,
    required this.onSeeAll,
  });

  final List<ProductCategory> categories;
  final ValueChanged<String> onSelected;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    // Show at most 8 from set_home.
    final visible = categories.length > 8 ? categories.sublist(0, 8) : categories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Категории', onSeeAll: onSeeAll),
        const SizedBox(height: 10),
        SizedBox(
          height: 86,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: visible.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index == visible.length) {
                return GestureDetector(
                  onTap: onSeeAll,
                  child: SizedBox(
                    width: 64,
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(Icons.grid_view_rounded, color: AppColors.purple, size: 24),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Все',
                          maxLines: 1,
                          style: TextStyle(
                            color: AppColors.purple,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final cat = visible[index];
              return InkWell(
                key: Key('home-category-${cat.name}'),
                borderRadius: BorderRadius.circular(14),
                onTap: () => onSelected(cat.name),
                child: SizedBox(
                  width: 64,
                  child: Column(
                    children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: ClipOval(
                          child: cat.imageUrl != null
                              ? _RetryImage(url: cat.imageUrl!, fit: BoxFit.cover)
                              : Container(
                                  color: AppColors.lavenderMid,
                                  child: const Icon(Icons.category_outlined, color: AppColors.purple, size: 24),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 24,
                        child: Text(
                          cat.name,
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
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

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

// ── Product grid ───────────────────────────────────────────────────────────────

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.provider});

  final MarketProvider provider;

  @override
  Widget build(BuildContext context) {
    final products = provider.filteredProducts.take(50).toList();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid.builder(
        itemCount: products.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.60,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemBuilder: (context, index) {
          final product = products[index];
          final cartQty = provider.cartQuantityFor(product.id);
          final canAdd =
              product.inStock && cartQty < product.stockQuantity;
          final hasDiscount = product.originalPrice != null &&
              product.originalPrice! > product.price;
          final discPct = hasDiscount
              ? ((1 - product.price / product.originalPrice!) * 100)
                  .round()
              : 0;
          final wishlist = context.watch<WishlistProvider>();
          final isFav = wishlist.isFavorite(product.id);

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
                  // Photo with optional discount + wishlist badges
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
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () async {
                              final token = await context
                                  .read<AuthProvider>()
                                  .getAccessToken();
                              wishlist.toggle(product,
                                  accessToken: token);
                            },
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(220),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isFav
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 16,
                                color: isFav
                                    ? Colors.redAccent
                                    : AppColors.navyMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Price row
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
                  // Packaging
                  if (product.packageInfo.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      product.packageInfo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navyMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Add / stepper
                  Align(
                    alignment: Alignment.centerRight,
                    child: cartQty > 0
                        ? _Stepper(
                            qty: cartQty,
                            canIncrement: canAdd,
                            onDecrement: () {
                              if (cartQty > 1) {
                                provider.updateQuantity(
                                    product.id, cartQty - 1);
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

// ── Horizontal product row (Best sellers / Last seen) ─────────────────────────

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
      height: 230,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final product = products[index];
          final cartQty = provider.cartQuantityFor(product.id);
          final canAdd =
              product.inStock && cartQty < product.stockQuantity;
          final hasDiscount = product.originalPrice != null &&
              product.originalPrice! > product.price;
          final wishlist = context.watch<WishlistProvider>();
          final isFav = wishlist.isFavorite(product.id);

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
                            child:
                                ProductImage(imageUrl: product.imageUrl),
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
                                color: const Color(0xFFFF4444),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '−${((1 - product.price / product.originalPrice!) * 100).round()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
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
                              final token = await context
                                  .read<AuthProvider>()
                                  .getAccessToken();
                              wishlist.toggle(product,
                                  accessToken: token);
                            },
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(220),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isFav
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 14,
                                color: isFav
                                    ? Colors.redAccent
                                    : AppColors.navyMuted,
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
                  if (product.packageInfo.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      product.packageInfo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.navyMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
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
                      if (cartQty > 0)
                        _Stepper(
                          qty: cartQty,
                          canIncrement: canAdd,
                          onDecrement: () {
                            if (cartQty > 1) {
                              provider.updateQuantity(
                                  product.id, cartQty - 1);
                            } else {
                              provider.removeFromCart(product.id);
                            }
                          },
                          onIncrement: canAdd
                              ? () => provider.addToCart(product)
                              : null,
                        )
                      else if (canAdd)
                        GestureDetector(
                          onTap: () => provider.addToCart(product),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: AppColors.purple,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.remove,
                            color: AppColors.navyMuted,
                            size: 14,
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

// ── Stepper ────────────────────────────────────────────────────────────────────

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
  const _StepBtn(
      {required this.icon, required this.onTap, required this.active});

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

// ── Add button ─────────────────────────────────────────────────────────────────

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
            color: widget.canAdd ? AppColors.purple : AppColors.border,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            Icons.add,
            size: 17,
            color:
                widget.canAdd ? Colors.white : AppColors.navyMuted,
          ),
        ),
      ),
    );
  }
}
