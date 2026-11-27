import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/banner_item.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/market_provider.dart';
import '../providers/wishlist_provider.dart';
import '../theme/app_theme.dart';
import '../config/app_config.dart';
import '../widgets/home/home_category_row.dart';
import '../widgets/home/home_city_chip.dart';
import '../widgets/home/home_hero_banner.dart';
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
  final ScrollController _scroll = ScrollController();

  /// CTA of an illustration banner: only existing destinations.
  Future<void> _openBannerAction(BannerItem banner) async {
    final value = banner.actionValue;
    if (value == null || value.isEmpty) return;
    if (banner.actionType == 'category') {
      widget.onCategorySelected(value);
      return;
    }
    if (banner.actionType == 'product') {
      final messenger = ScaffoldMessenger.of(context);
      final product =
          await context.read<MarketProvider>().fetchProductById(value);
      if (!mounted) return;
      if (product == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Товар недоступен')),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
      );
    }
  }

  void _openBanner(BannerItem banner) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PromotionDetailScreen(bannerId: banner.id),
        ),
      );

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scroll.dispose();
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
      // Below the decorative image the page continues in its bottom colour.
      backgroundColor: AppColors.peachBottom,
      body: Stack(
        children: [
          _HomeBackground(scroll: _scroll),
          SafeArea(
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
                controller: _scroll,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    sliver: SliverList.list(
                      children: [
                        const _Header(),
                        const SizedBox(height: 8),
                        _SearchBar(
                          controller: _searchCtrl,
                          onSubmitted: (value) {
                            provider.setSearchQuery(value);
                            provider.loadProducts();
                            widget.onSearchSubmitted();
                          },
                        ),
                        const SizedBox(height: 12),
                        if (provider.bannersLoading) ...[
                          const HomeHeroSkeleton(),
                          const SizedBox(height: 14),
                        ] else if (heroBanners.isNotEmpty) ...[
                          HomeHeroCarousel(
                            banners: heroBanners,
                            onOpen: (b) => b.isIllustration && b.hasAction
                                ? _openBannerAction(b)
                                : _openBanner(b),
                            onAction: _openBannerAction,
                          ),
                          const SizedBox(height: 14),
                        ],
                        HomeCategoryRow(
                          categories: provider.homeCategoryObjects,
                          onSelected: widget.onCategorySelected,
                          onSeeAll: () => widget.onCategorySelected('All'),
                        ),
                        const SizedBox(height: 14),
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
                          const SizedBox(height: 22),
                          const _SectionHeader(
                            title: 'Специальные предложения',
                          ),
                          const SizedBox(height: 10),
                          _SpecialOffers(
                            offers: specialOffers,
                            onTap: (b) =>
                                b.hasAction ? _openBannerAction(b) : _openBanner(b),
                          ),
                        ],
                        if (provider.featuredLoading) ...[
                          const SizedBox(height: 22),
                          const _SkeletonBox(height: 18, width: 160, radius: 6),
                          const SizedBox(height: 10),
                          const _SkeletonHorizontalRow(),
                        ] else if (provider.featuredProducts.isNotEmpty) ...[
                          const SizedBox(height: 22),
                          _SectionHeader(
                            title: 'Лучшие предложения',
                            onSeeAll: () => widget.onCategorySelected('All'),
                          ),
                          const SizedBox(height: 10),
                          _HorizontalProductRow(
                            products: provider.featuredProducts,
                            provider: provider,
                          ),
                        ],
                        if (provider.bestSellersLoading) ...[
                          const SizedBox(height: 22),
                          const _SkeletonBox(height: 18, width: 140, radius: 6),
                          const SizedBox(height: 14),
                          const _SkeletonHorizontalRow(),
                        ] else if (provider.bestSellerProducts.isNotEmpty) ...[
                          const SizedBox(height: 22),
                          _SectionHeader(
                            title: 'Хиты продаж',
                            onSeeAll: () => widget.onCategorySelected('All'),
                          ),
                          const SizedBox(height: 10),
                          _HorizontalProductRow(
                            products: provider.bestSellerProducts,
                            provider: provider,
                          ),
                        ],
                        if (provider.newArrivalsLoading) ...[
                          const SizedBox(height: 22),
                          const _SkeletonBox(height: 18, width: 110, radius: 6),
                          const SizedBox(height: 14),
                          const _SkeletonHorizontalRow(),
                        ] else if (provider.newArrivalProducts.isNotEmpty) ...[
                          const SizedBox(height: 22),
                          _SectionHeader(
                            title: 'Новинки',
                            onSeeAll: () => widget.onCategorySelected('All'),
                          ),
                          const SizedBox(height: 10),
                          _HorizontalProductRow(
                            products: provider.newArrivalProducts,
                            provider: provider,
                          ),
                        ],
                        if (provider.lastSeenProducts.isNotEmpty) ...[
                          const SizedBox(height: 22),
                          const _SectionHeader(title: 'Недавно просмотренные'),
                          const SizedBox(height: 10),
                          _HorizontalProductRow(
                            products: provider.lastSeenProducts,
                            provider: provider,
                          ),
                        ],
                        const SizedBox(height: 22),
                        _SectionHeader(
                          title: 'Популярные товары',
                          onSeeAll: () => widget.onCategorySelected('All'),
                        ),
                        const SizedBox(height: 10),
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
        ],
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
              const SizedBox(height: 8),
              const _SkeletonBox(height: 44, radius: 22),
              const SizedBox(height: 12),
              const HomeHeroSkeleton(),
              const SizedBox(height: 14),
              // Horizontal circle skeletons for category strip
              SizedBox(
                height: 86,
                child: Row(
                  children: List.generate(5, (i) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Column(
                      children: [
                        const _SkeletonBox(height: 60, width: 60, radius: AppRadii.image),
                        const SizedBox(height: 6),
                        Container(
                          height: 10,
                          width: 46,
                          decoration: BoxDecoration(
                            color: AppColors.peachSoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  )),
                ),
              ),
              const SizedBox(height: 22),
              const _SkeletonBox(height: 18, width: 160, radius: 6),
              const SizedBox(height: 14),
              const _SkeletonHorizontalRow(),
              const SizedBox(height: 22),
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

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 44,
      child: Row(
        children: [
          // Code-drawn wordmark approximating the client's «YO market» logo
          // (no vector file provided yet) — not an exact copy.
          YoMarketLogo(height: 26),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (AppConfig.uiPreview) _PreviewBadge(),
                Flexible(child: HomeCityChip()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Marks UI_PREVIEW builds: Home shows fixture data, not the live API.
class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: const BoxDecoration(
        color: AppColors.warnSoft,
        borderRadius: AppRadii.chipBorder,
      ),
      child: const Text(
        'Превью',
        style: TextStyle(
          color: AppColors.warn,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Client's decorative background, pinned to the top of the scroll content:
/// it scrolls away with the page, is never repeated or stretched to the
/// scroll height; below it the page continues in [AppColors.peachBottom]
/// (the image's bottom-edge colour).
class _HomeBackground extends StatelessWidget {
  const _HomeBackground({required this.scroll});

  final ScrollController scroll;

  static const asset = 'assets/images/home/home_background.webp';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scroll,
      builder: (context, child) {
        final offset = scroll.hasClients ? scroll.offset.clamp(0.0, 4000.0) : 0.0;
        return Positioned(
          top: -offset,
          left: 0,
          right: 0,
          child: child!,
        );
      },
      child: const IgnorePointer(
        child: Image(
          image: AssetImage(asset),
          fit: BoxFit.fitWidth,
          alignment: Alignment.topCenter,
          excludeFromSemantics: true,
          gaplessPlayback: true,
        ),
      ),
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
        isDense: true,
        constraints: const BoxConstraints(minHeight: 44),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
            // Two lines at large text sizes instead of cutting the heading.
            maxLines: 2,
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
    // Two per row while the copy fits; one per row at large text sizes.
    final scale = MediaQuery.textScalerOf(context).scale(15) / 15;
    final cardWidth =
        (MediaQuery.sizeOf(context).width - 2 * 16 - AppSpacing.md) / 2;
    final perRow = cardWidth >= 165 * scale ? 2 : 1;
    final rows = <Widget>[];
    for (var i = 0; i < offers.length; i += perRow) {
      final pair = offers.skip(i).take(perRow).toList();
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
