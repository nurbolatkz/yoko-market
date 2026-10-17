import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/market_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/product_image.dart';
import 'product_detail_screen.dart';

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
                  const SizedBox(height: 14),
                  _SearchField(provider: provider),
                  const SizedBox(height: 18),
                  _HeroBanner(onShopTap: onCategorySelected),
                  const SizedBox(height: 22),
                  _Categories(onSelected: onCategorySelected),
                  const SizedBox(height: 28),
                  const _SectionHeader(title: 'Популярные бренды'),
                  const SizedBox(height: 12),
                  const _Brands(),
                  const SizedBox(height: 24),
                  const _PromotionBanner(),
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
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontFamily: 'Roboto',
              letterSpacing: -0.5,
            ),
            children: [
              TextSpan(
                text: 'Y',
                style: TextStyle(
                  color: AppColors.purple,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              TextSpan(
                text: 'o',
                style: TextStyle(
                  color: AppColors.yellow,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              TextSpan(
                text: ' Market',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Уведомления',
          onPressed: () {},
          icon: const Icon(
            Icons.notifications_none_rounded,
            size: 26,
            color: AppColors.navy,
          ),
        ),
      ],
    );
  }
}

// ── Search ────────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({required this.provider});

  final MarketProvider provider;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: provider.setSearchQuery,
      style: const TextStyle(color: AppColors.navy, fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Поиск товаров...',
        hintStyle: const TextStyle(color: AppColors.navyMuted),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 22,
          color: AppColors.navyMuted,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
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

// ── Hero banner ───────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.onShopTap});

  final ValueChanged<String> onShopTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = (constraints.maxWidth / 2.5).clamp(140.0, 178.0);

        return ClipRRect(
          borderRadius: AppRadii.cardBorder,
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // photo
                Image.asset(
                  'assets/images/hero_banner.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                ),
                // left overlay so text stays readable on any photo
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withAlpha(220),
                        Colors.white.withAlpha(0),
                      ],
                      stops: const [0.45, 1.0],
                    ),
                  ),
                ),
                // text + button
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * .50,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'YokoSun',
                            style: TextStyle(
                              color: AppColors.purple,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Всё для\nмалыша',
                            maxLines: 2,
                            style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            height: 38,
                            child: FilledButton(
                              onPressed: () => onShopTap(''),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.yellow,
                                foregroundColor: AppColors.navy,
                                minimumSize: const Size(100, 38),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                                shape: const StadiumBorder(),
                              ),
                              child: const Text('В каталог  →'),
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
      },
    );
  }
}

// ── Categories ────────────────────────────────────────────────────────────

class _Categories extends StatelessWidget {
  const _Categories({required this.onSelected});

  final ValueChanged<String> onSelected;

  static const _items = [
    ('Подгузники', Icons.baby_changing_station_rounded),
    ('Детская\nкосметика', Icons.spa_outlined),
    ('Бытовая\nхимия', Icons.cleaning_services_outlined),
    ('Салфетки', Icons.layers_outlined),
    ('Другое', Icons.toys_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _items
          .map(
            (item) => Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onSelected(item.$1.replaceAll('\n', ' ')),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
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
                            item.$2,
                            color: AppColors.purple,
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      SizedBox(
                        height: 31,
                        child: Text(
                          item.$1,
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
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

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
    );
  }
}

// ── Brands ────────────────────────────────────────────────────────────────

class _Brands extends StatelessWidget {
  const _Brands();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _Brand(name: 'YokoSun', color: Color(0xFF2B246E)),
        SizedBox(width: 8),
        _Brand(name: 'FUTARI', color: Color(0xFFD77C93)),
        SizedBox(width: 8),
        _Brand(name: 'Comfy', color: Color(0xFF168BAD)),
        SizedBox(width: 8),
        _Brand(name: 'AURA', color: Color(0xFF1754B0)),
      ],
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              name,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Promotion banner ──────────────────────────────────────────────────────

class _PromotionBanner extends StatelessWidget {
  const _PromotionBanner();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = (constraints.maxWidth / 3.4).clamp(90.0, 120.0);

        return ClipRRect(
          borderRadius: AppRadii.cardBorder,
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/promotion_banner.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withAlpha(200),
                        Colors.white.withAlpha(0),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: .55,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Скидки до 30%',
                              style: TextStyle(
                                color: AppColors.navy,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'На товары для малышей',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.navyMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
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
      },
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
          final canAdd =
              product.inStock && cartQty < product.stockQuantity;

          return InkWell(
            borderRadius: AppRadii.cardBorder,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(product: product),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
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
                  const SizedBox(height: 8),
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    !product.inStock
                        ? 'Нет в наличии'
                        : canAdd
                            ? 'В наличии'
                            : 'Максимум в корзине',
                    maxLines: 1,
                    style: TextStyle(
                      color: !product.inStock
                          ? Colors.red.shade600
                          : canAdd
                              ? const Color(0xFF1E7D47)
                              : AppColors.navyMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          '${product.price.toStringAsFixed(0)} ₸',
                          maxLines: 1,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
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
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: widget.canAdd ? AppColors.yellow : AppColors.border,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.add,
            size: 18,
            color: widget.canAdd ? AppColors.navy : AppColors.navyMuted,
          ),
        ),
      ),
    );
  }
}
