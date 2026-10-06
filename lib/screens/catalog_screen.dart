import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/market_provider.dart';
import '../theme/app_theme.dart';
import 'product_detail_screen.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key, required this.onCategorySelected});

  final ValueChanged<String> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MarketProvider>();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          key: const Key('home-scroll'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverList.list(
                children: [
                  const _Header(),
                  const SizedBox(height: 14),
                  _SearchField(provider: provider),
                  const SizedBox(height: 16),
                  const _HeroBanner(),
                  const SizedBox(height: 18),
                  _Categories(onSelected: onCategorySelected),
                  const SizedBox(height: 26),
                  const _SectionHeader(title: 'Популярные бренды'),
                  const SizedBox(height: 12),
                  const _Brands(),
                  const SizedBox(height: 20),
                  const _PromotionBanner(),
                  const SizedBox(height: 26),
                  const _SectionHeader(title: 'Популярные товары'),
                  const SizedBox(height: 12),
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

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RichText(
          text: const TextSpan(
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
            children: [
              TextSpan(
                text: 'Y',
                style: TextStyle(color: AppColors.purple, fontSize: 34),
              ),
              TextSpan(
                text: 'o',
                style: TextStyle(color: AppColors.yellow, fontSize: 34),
              ),
              TextSpan(text: ' Market'),
            ],
          ),
        ),
        const Spacer(),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'Уведомления',
              onPressed: () {},
              icon: const Icon(Icons.notifications_none_rounded, size: 28),
            ),
            const Positioned(
              right: 8,
              top: 7,
              child: CircleAvatar(radius: 4, backgroundColor: AppColors.purple),
            ),
          ],
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.provider});

  final MarketProvider provider;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: provider.setSearchQuery,
      decoration: const InputDecoration(
        hintText: 'Поиск товаров...',
        prefixIcon: Icon(Icons.search_rounded, size: 28),
        suffixIcon: Icon(Icons.tune_rounded, size: 23),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = (constraints.maxWidth / 2.65).clamp(140.0, 170.0);

        return ClipRRect(
          borderRadius: AppRadii.cardBorder,
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/hero_banner.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 15, 12, 14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * .48,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'YokoSun',
                            maxLines: 1,
                            style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 7),
                          const Text(
                            'Забота\nс первых дней',
                            maxLines: 2,
                            style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 15,
                              height: 1.12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            height: 38,
                            child: FilledButton(
                              onPressed: () {},
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(110, 38),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                ),
                                shape: const StadiumBorder(),
                              ),
                              child: const Text('Купить  →'),
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

class _Categories extends StatelessWidget {
  const _Categories({required this.onSelected});

  final ValueChanged<String> onSelected;

  static const items = [
    ('Подгузники', Icons.baby_changing_station_rounded, Color(0xFFDDEEFF)),
    ('Детская\nкосметика', Icons.spa_outlined, Color(0xFFFFE5EC)),
    ('Бытовая\nхимия', Icons.cleaning_services_outlined, Color(0xFFE6F3D9)),
    ('Салфетки', Icons.layers_outlined, Color(0xFFDDEEFF)),
    ('Другое', Icons.toys_outlined, Color(0xFFF0E7FF)),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
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
                          constraints: const BoxConstraints(maxWidth: 64),
                          decoration: BoxDecoration(
                            color: item.$3,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            item.$2,
                            color: AppColors.purple,
                            size: 27,
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
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(width: 12),
        TextButton(onPressed: () {}, child: const Text('Все  →')),
      ],
    );
  }
}

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
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
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
    );
  }
}

class _PromotionBanner extends StatelessWidget {
  const _PromotionBanner();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = (constraints.maxWidth / 3.55).clamp(88.0, 116.0);

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
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 17,
                    vertical: 12,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: .56,
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
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'На товары для малышей',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.navyMuted,
                                  fontWeight: FontWeight.w600,
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
                color: AppColors.surface,
                borderRadius: AppRadii.cardBorder,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.purpleSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        size: 56,
                        color: AppColors.purple,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
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
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => provider.addToCart(product),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.purple,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.add, color: Colors.white),
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
