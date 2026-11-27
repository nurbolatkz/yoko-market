import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/banner_item.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/market_provider.dart';
import '../providers/wishlist_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/home/home_category_row.dart';
import '../widgets/home/home_info_tiles.dart';
import '../widgets/home/special_offer_card.dart';
import '../widgets/yo_market_logo.dart';
import '../widgets/ui/app_product_card.dart';
import '../widgets/ui/error_state.dart';
import 'delivery_info_screen.dart';
import 'product_detail_screen.dart';
import 'promotion_detail_screen.dart';
import 'yocoin_screen.dart';

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

  void _openBanner(BannerItem banner) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PromotionDetailScreen(bannerId: banner.id),
        ),
      );

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

    final heroBanners =
        provider.banners.where((b) => !b.isSpecialOffer).toList();
    final specialOffers =
        provider.banners.where((b) => b.isSpecialOffer).toList();

    return Scaffold(
      backgroundColor: AppColors.peachBottom,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.homeBackground),
        child: SafeArea(
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
                        const SizedBox(height: 16),
                        if (provider.bannersLoading)
                          const _SkeletonBox(height: 170, radius: AppRadii.card)
                        else if (heroBanners.isNotEmpty) ...[
                          _BannerCarousel(banners: heroBanners),
                          const SizedBox(height: 20),
                        ],
                        HomeCategoryRow(
                          categories: provider.homeCategoryObjects,
                          onSelected: widget.onCategorySelected,
                          onSeeAll: () => widget.onCategorySelected('All'),
                        ),
                        const SizedBox(height: 20),
                        HomeInfoTiles(
                          maxCashbackPercent: provider.maxCashbackPercent,
                          freeDeliveryFrom: provider.freeDeliveryFrom,
                          onBonusTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const YoCoinScreen(),
                            ),
                          ),
                          onDeliveryTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DeliveryInfoScreen(),
                            ),
                          ),
                        ),
                        if (specialOffers.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          const _SectionHeader(
                            title: 'Специальные предложения',
                          ),
                          const SizedBox(height: 14),
                          _SpecialOffers(
                            offers: specialOffers,
                            onTap: _openBanner,
                          ),
                        ],
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
                  SliverToBoxAdapter(child: const SizedBox(height: 24)),
                ],
              ),
          ],
        ),
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
    return const Align(
      alignment: Alignment.centerLeft,
      child: YoMarketLogo(height: 34),
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
            const TextStyle(color: AppColors.navyMuted, fontSize: 15),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.navyMuted,
          size: 20,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide:
              const BorderSide(color: AppColors.brandOrange, width: 1.5),
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
            (constraints.maxWidth / 2.05).clamp(150.0, 220.0);
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
                          ? AppColors.brandRed
                          : AppColors.peachTop,
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
              color: AppColors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (onSeeAll != null) ...[
          const SizedBox(width: 12),
          Semantics(
            button: true,
            label: 'Все: $title',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: onSeeAll,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Все',
                      style: TextStyle(
                        color: AppColors.brandRed,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: AppColors.brandRed,
                    ),
                  ],
                ),
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
          final canAdd = product.inStock && cartQty < product.stockQuantity;
          final wishlist = context.watch<WishlistProvider>();
          final isFav = wishlist.isFavorite(product.id);

          return AppProductCard(
            product: product,
            cartQty: cartQty,
            isFavorite: isFav,
            imageKeyPrefix: 'home',
            onTap: () {
              context.read<MarketProvider>().recordView(product);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(product: product),
                ),
              );
            },
            onFavorite: () async {
              final token =
                  await context.read<AuthProvider>().getAccessToken();
              wishlist.toggle(product, accessToken: token);
            },
            onAdd: canAdd ? () => provider.addToCart(product) : null,
            onDecrement: () {
              if (cartQty > 1) {
                provider.updateQuantity(product.id, cartQty - 1);
              } else {
                provider.removeFromCart(product.id);
              }
            },
            onIncrement: canAdd ? () => provider.addToCart(product) : null,
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

  static const _cardWidth = 160.0;

  @override
  Widget build(BuildContext context) {
    final wishlist = context.watch<WishlistProvider>();
    // Same proportions as the 2-column grid card, grown with text scale.
    final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
    final height = _cardWidth / 0.60 + (scale - 1) * 60;
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: EdgeInsets.zero,
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) {
          final product = products[index];
          final cartQty = provider.cartQuantityFor(product.id);
          final canAdd = product.inStock && cartQty < product.stockQuantity;
          return SizedBox(
            width: _cardWidth,
            child: AppProductCard(
              product: product,
              cartQty: cartQty,
              isFavorite: wishlist.isFavorite(product.id),
              imageKeyPrefix: 'home-row',
              onTap: () {
                provider.recordView(product);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(product: product),
                  ),
                );
              },
              onFavorite: () async {
                final token =
                    await context.read<AuthProvider>().getAccessToken();
                wishlist.toggle(product, accessToken: token);
              },
              onAdd: canAdd ? () => provider.addToCart(product) : null,
              onDecrement: () {
                if (cartQty > 1) {
                  provider.updateQuantity(product.id, cartQty - 1);
                } else {
                  provider.removeFromCart(product.id);
                }
              },
              onIncrement: canAdd ? () => provider.addToCart(product) : null,
            ),
          );
        },
      ),
    );
  }
}

// ── Special offers (banners with placement: special) ──────────────────────────

class _SpecialOffers extends StatelessWidget {
  const _SpecialOffers({required this.offers, required this.onTap});

  final List<BannerItem> offers;
  final ValueChanged<BannerItem> onTap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < offers.length; i += 2) {
      final pair = offers.skip(i).take(2).toList();
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.md));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var k = 0; k < pair.length; k++) ...[
                if (k > 0) const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 168),
                    child: SpecialOfferCard(
                      banner: pair[k],
                      onTap: () => onTap(pair[k]),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}
