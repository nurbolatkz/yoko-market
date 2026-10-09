import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/market_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/product_image.dart';
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
      if (!provider.catalogLoading && !provider.isLoadingMore && provider.hasMore) {
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
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Text(
                'Каталог',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
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
                          onPressed: () => _showFilterSheet(context, provider),
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
            SizedBox(
              height: 62,
              child: ListView.separated(
                key: const Key('catalog-categories'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: provider.categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = provider.categories[index];
                  final selected = provider.selectedCategory == category;

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
                      color: selected ? AppColors.purple : AppColors.border,
                    ),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.navy,
                      fontWeight: FontWeight.w600,
                    ),
                    showCheckmark: false,
                  );
                },
              ),
            ),
            // Count label: only show when we have all results (hasMore = false)
            // to avoid showing a partial loaded count as the total.
            if (!provider.hasMore && products.isNotEmpty && !provider.catalogLoading)
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
            Expanded(
              child: provider.catalogLoading && products.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : provider.catalogError != null
                  ? _CatalogLoadError(
                      message: provider.catalogError!,
                      onRetry: provider.loadCatalog,
                    )
                  : products.isEmpty
                  ? _EmptyCatalog(
                      onReset: () {
                        _searchController.clear();
                        _scrollToTop();
                        provider.resetCatalogFilters();
                      },
                    )
                  : Stack(
                      children: [
                        RefreshIndicator(
                          onRefresh: () =>
                              context.read<MarketProvider>().loadCatalog(),
                          child: CustomScrollView(
                            key: const Key('catalog-grid'),
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                                sliver: SliverGrid(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        mainAxisExtent: 272,
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 10,
                                      ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) => CatalogProductCard(
                                      product: products[index],
                                      isFavorite: provider.isFavorite(
                                        products[index].id,
                                      ),
                                      onFavorite: () => provider.toggleFavorite(
                                        products[index].id,
                                      ),
                                      onAdd: () =>
                                          provider.addToCart(products[index]),
                                      onOpen: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ProductDetailScreen(
                                            product: products[index],
                                          ),
                                        ),
                                      ),
                                    ),
                                    childCount: products.length,
                                  ),
                                ),
                              ),
                              if (provider.isLoadingMore)
                                const SliverToBoxAdapter(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 80),
                              ),
                            ],
                          ),
                        ),
                        if (provider.catalogLoading)
                          const Align(
                            alignment: Alignment.topCenter,
                            child: LinearProgressIndicator(),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
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
            const Text('Сортировка по популярности применяется по умолчанию.'),
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

class CatalogProductCard extends StatelessWidget {
  const CatalogProductCard({
    super.key,
    required this.product,
    required this.isFavorite,
    required this.onFavorite,
    required this.onAdd,
    required this.onOpen,
  });

  final Product product;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onAdd;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadii.cardBorder,
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Product image (slightly shorter) ────────────────────
              SizedBox(
                height: 120,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ProductImage(
                        key: Key('catalog-product-image-${product.id}'),
                        imageUrl: product.imageUrl,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: Colors.white.withValues(alpha: .92),
                        shape: const CircleBorder(),
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: isFavorite
                              ? 'Убрать из избранного'
                              : 'В избранное',
                          onPressed: onFavorite,
                          icon: Icon(
                            isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isFavorite
                                ? AppColors.purple
                                : AppColors.navy,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // ── Name (up to 3 lines) ─────────────────────────────────
              Text(
                product.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 13,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              // ── Package / size info ──────────────────────────────────
              if (product.packageInfo.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  product.packageInfo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navyMuted,
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              // ── Stock status (no quantity number) ────────────────────
              Text(
                product.inStock ? 'В наличии' : 'Нет в наличии',
                maxLines: 1,
                style: TextStyle(
                  color: product.inStock
                      ? const Color(0xFF23804A)
                      : Colors.red.shade700,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // ── Price + add button ───────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${product.price.toStringAsFixed(0)} ₸',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton.filled(
                    key: Key('add-${product.id}'),
                    tooltip: product.inStock ? 'Добавить в корзину' : 'Нет в наличии',
                    onPressed: product.inStock ? onAdd : null,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.purple,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.border,
                      disabledForegroundColor: AppColors.navyMuted,
                      minimumSize: const Size(34, 34),
                      maximumSize: const Size(34, 34),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogLoadError extends StatelessWidget {
  const _CatalogLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 52,
              color: AppColors.purple,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.search_off_rounded,
                  size: 48,
                  color: AppColors.purple,
                ),
                const SizedBox(height: 8),
                Text(
                  'Товары не найдены',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Измените запрос или сбросьте выбранные фильтры.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: onReset,
                  child: const Text('Сбросить фильтры'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
