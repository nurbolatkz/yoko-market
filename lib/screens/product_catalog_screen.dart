import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/market_provider.dart';
import '../providers/wishlist_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/app_product_card.dart';
import '../widgets/ui/empty_state.dart';
import '../widgets/ui/error_state.dart';
import 'product_detail_screen.dart';

class ProductCatalogScreen extends StatefulWidget {
  const ProductCatalogScreen({super.key});

  @override
  State<ProductCatalogScreen> createState() => _ProductCatalogScreenState();
}

class _ProductCatalogScreenState extends State<ProductCatalogScreen> {
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  void _onScroll() {
    if (!mounted) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      final provider = context.read<MarketProvider>();
      if (!provider.catalogLoading &&
          !provider.isLoadingMore &&
          provider.hasMore) {
        provider.loadMoreProducts();
      }
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final query = context.read<MarketProvider>().searchQuery;
    if (_searchController.text != query) {
      _searchController.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MarketProvider>();
    final products = provider.filteredProducts;

    return Scaffold(
      backgroundColor: AppColors.homeBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Text(
                'Каталог',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            // ── Search ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                key: const Key('catalog-search'),
                controller: _searchController,
                onChanged: (value) {
                  provider.setSearchQuery(value);
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 350),
                    () {
                      _scrollToTop();
                      provider.loadProducts();
                    },
                  );
                },
                decoration: InputDecoration(
                  hintText: 'Поиск товаров...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: provider.searchQuery.isEmpty
                      ? IconButton(
                          tooltip: 'Фильтры',
                          icon: const Icon(Icons.tune_rounded),
                          onPressed: () =>
                              _showFilterSheet(context, provider),
                        )
                      : IconButton(
                          tooltip: 'Очистить поиск',
                          onPressed: () {
                            _searchController.clear();
                            provider.setSearchQuery('');
                            _scrollToTop();
                            provider.loadProducts();
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            // ── Category chips ───────────────────────────────────────
            SizedBox(
              height: 54,
              child: ListView.separated(
                key: const Key('catalog-categories'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                itemCount: provider.categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = provider.categories[index];
                  final selected =
                      provider.selectedCategory == category;
                  return ChoiceChip(
                    label: Text(category == 'All' ? 'Все' : category),
                    selected: selected,
                    onSelected: (_) {
                      provider.setSelectedCategory(category);
                      _scrollToTop();
                      provider.loadProducts();
                    },
                    selectedColor: AppColors.purple,
                    backgroundColor: AppColors.surface,
                    side: BorderSide(
                      color: selected
                          ? AppColors.purple
                          : AppColors.border,
                    ),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.navy,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),
            // ── Product count ────────────────────────────────────────
            if (!provider.hasMore &&
                products.isNotEmpty &&
                !provider.catalogLoading)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                child: Text(
                  '${products.length} ${_productWord(products.length)}',
                  key: const Key('catalog-product-count'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.navyMuted,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              )
            else
              const SizedBox(height: 10),
            // ── Content area ─────────────────────────────────────────
            Expanded(
              child: _buildContent(context, provider, products),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    MarketProvider provider,
    List<Product> products,
  ) {
    if (provider.catalogLoading && products.isEmpty) {
      return _CatalogLoadingSkeleton(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.60,
      );
    }
    if (provider.catalogError != null && products.isEmpty) {
      return Center(
        child: ErrorState(
          message: provider.catalogError,
          onRetry: provider.loadCatalog,
        ),
      );
    }
    if (products.isEmpty) {
      return _EmptyCatalog(
        onReset: () {
          _searchController.clear();
          _scrollToTop();
          provider.resetCatalogFilters();
        },
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => context.read<MarketProvider>().loadCatalog(),
          child: CustomScrollView(
            key: const Key('catalog-grid'),
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.60,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final p = products[index];
                      final cartQty =
                          provider.cartQuantityFor(p.id);
                      final canAdd = p.inStock &&
                          cartQty < p.stockQuantity;
                      final wishlist =
                          context.watch<WishlistProvider>();
                      return AppProductCard(
                        product: p,
                        cartQty: cartQty,
                        isFavorite: wishlist.isFavorite(p.id),
                        imageKeyPrefix: 'catalog',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProductDetailScreen(product: p),
                          ),
                        ),
                        onFavorite: () async {
                          final token = await context
                              .read<AuthProvider>()
                              .getAccessToken();
                          if (!context.mounted) return;
                          context
                              .read<WishlistProvider>()
                              .toggle(p, accessToken: token);
                        },
                        onAdd: canAdd
                            ? () => provider.addToCart(p)
                            : null,
                        onDecrement: () {
                          if (cartQty > 1) {
                            provider.updateQuantity(
                                p.id, cartQty - 1);
                          } else {
                            provider.removeFromCart(p.id);
                          }
                        },
                        onIncrement: canAdd
                            ? () => provider.addToCart(p)
                            : null,
                      );
                    },
                    childCount: products.length,
                  ),
                ),
              ),
              if (provider.isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
            ],
          ),
        ),
        if (provider.catalogLoading && products.isNotEmpty)
          const Align(
            alignment: Alignment.topCenter,
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }

  void _showFilterSheet(BuildContext context, MarketProvider provider) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Сортировка и фильтры',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const Text(
                'Сортировка по популярности применяется по умолчанию.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Понятно'),
            ),
          ],
        ),
      ),
    );
  }

  String _productWord(int count) {
    final lastTwo = count % 100;
    if (lastTwo >= 11 && lastTwo <= 14) return 'товаров';
    return switch (count % 10) {
      1 => 'товар',
      2 || 3 || 4 => 'товара',
      _ => 'товаров',
    };
  }
}

// ── Loading skeleton ────────────────────────────────────────────────────────────

class _CatalogLoadingSkeleton extends StatelessWidget {
  const _CatalogLoadingSkeleton({
    required this.crossAxisCount,
    required this.crossAxisSpacing,
    required this.mainAxisSpacing,
    required this.childAspectRatio,
  });

  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
      ),
      itemCount: 6,
      itemBuilder: (_, _) => Container(
        decoration: BoxDecoration(
          color: AppColors.lavenderMid,
          borderRadius: AppRadii.cardBorder,
        ),
      ),
    );
  }
}

// ── Empty state ─────────────────────────────────────────────────────────────────

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog({required this.onReset});
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MarketProvider>();
    final popular = provider.featuredProducts.take(4).toList();

    return SingleChildScrollView(
      child: EmptyState(
        headline: 'Ничего не найдено',
        body: 'Попробуйте другое название или сбросьте фильтры.',
        actionLabel: 'Сбросить фильтры',
        onAction: onReset,
        bottom: popular.isEmpty
            ? null
            : _SearchSuggestions(products: popular),
      ),
    );
  }
}

class _SearchSuggestions extends StatelessWidget {
  const _SearchSuggestions({required this.products});
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketProvider>();
    final wishlist = context.watch<WishlistProvider>();
    final auth = context.read<AuthProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Возможно, вам понравится',
          style: TextStyle(
            fontFamily: 'NunitoSans',
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.60,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: products.length,
          itemBuilder: (context, i) {
            final p = products[i];
            final cartQty = market.cartQuantityFor(p.id);
            final canAdd =
                p.inStock && cartQty < p.stockQuantity;
            return AppProductCard(
              product: p,
              cartQty: cartQty,
              isFavorite: wishlist.isFavorite(p.id),
              imageKeyPrefix: 'catalog-suggest',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(product: p),
                ),
              ),
              onFavorite: () async {
                final token = await auth.getAccessToken();
                if (!context.mounted) return;
                context
                    .read<WishlistProvider>()
                    .toggle(p, accessToken: token);
              },
              onAdd: canAdd ? () => market.addToCart(p) : null,
              onDecrement: () {
                if (cartQty > 1) {
                  market.updateQuantity(p.id, cartQty - 1);
                } else {
                  market.removeFromCart(p.id);
                }
              },
              onIncrement: canAdd ? () => market.addToCart(p) : null,
            );
          },
        ),
      ],
    );
  }
}
