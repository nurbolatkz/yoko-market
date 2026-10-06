import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/market_provider.dart';
import 'product_detail_screen.dart';

const _purple = Color(0xFF6750F5);
const _ink = Color(0xFF17152F);

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MarketProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9FF),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverList.list(
                children: [
                  const _Header(),
                  const SizedBox(height: 14),
                  _SearchBar(provider: provider),
                  const SizedBox(height: 14),
                  const _HeroBanner(),
                  const SizedBox(height: 18),
                  const _Categories(),
                  const SizedBox(height: 24),
                  const _SectionTitle(title: 'Популярные бренды'),
                  const SizedBox(height: 12),
                  const _Brands(),
                  const SizedBox(height: 18),
                  const _SaleBanner(),
                  const SizedBox(height: 24),
                  const _SectionTitle(title: 'Популярные товары'),
                  const SizedBox(height: 12),
                  _Products(provider: provider),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) => Row(
    children: [
      RichText(
        text: const TextSpan(
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: _ink,
          ),
          children: [
            TextSpan(
              text: 'Y',
              style: TextStyle(color: _purple, fontSize: 32),
            ),
            TextSpan(
              text: 'o',
              style: TextStyle(color: Color(0xFFFFC32B), fontSize: 32),
            ),
            TextSpan(text: ' Market'),
          ],
        ),
      ),
      const Spacer(),
      IconButton(
        onPressed: () {},
        icon: const Icon(Icons.notifications_none_rounded),
      ),
    ],
  );
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.provider});
  final MarketProvider provider;
  @override
  Widget build(BuildContext context) => TextField(
    onChanged: provider.setSearchQuery,
    decoration: InputDecoration(
      hintText: 'Поиск товаров...',
      hintStyle: const TextStyle(color: Color(0xFFAAA8B8)),
      prefixIcon: const Icon(Icons.search_rounded),
      suffixIcon: const Icon(Icons.tune_rounded, size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.zero,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();
  @override
  Widget build(BuildContext context) => Container(
    height: 170,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(
        colors: [Color(0xFFD9E7FF), Color(0xFFF3EEFF)],
      ),
    ),
    child: Stack(
      children: [
        Positioned(
          right: -5,
          bottom: -18,
          child: Icon(
            Icons.child_care_rounded,
            size: 145,
            color: Colors.white.withValues(alpha: .82),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'YokoSun',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: _ink,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'Забота\nс первых дней',
              style: TextStyle(
                fontSize: 16,
                height: 1.18,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Купить'),
                  SizedBox(width: 9),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Categories extends StatelessWidget {
  const _Categories();
  static const data = [
    ('Подгузники', Icons.baby_changing_station_rounded, Color(0xFFD9F4FF)),
    ('Детская\nкосметика', Icons.spa_outlined, Color(0xFFFFE6EF)),
    ('Бытовая\nхимия', Icons.cleaning_services_outlined, Color(0xFFE4F4DB)),
    ('Салфетки', Icons.layers_outlined, Color(0xFFDFF2FF)),
    ('Другое', Icons.more_horiz_rounded, Color(0xFFE9E2FF)),
  ];
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: data
        .map(
          (item) => Expanded(
            child: Column(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: item.$3,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(item.$2, color: _purple, size: 27),
                ),
                const SizedBox(height: 7),
                Text(
                  item.$1,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        )
        .toList(),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: _ink,
        ),
      ),
      const Spacer(),
      const Text(
        'Все  →',
        style: TextStyle(color: _purple, fontWeight: FontWeight.w600),
      ),
    ],
  );
}

class _Brands extends StatelessWidget {
  const _Brands();
  @override
  Widget build(BuildContext context) => const Row(
    children: [
      _Brand(name: 'YokoSun', color: Color(0xFF2B246E)),
      SizedBox(width: 9),
      _Brand(name: 'FUTARI', color: Color(0xFFD77C93)),
      SizedBox(width: 9),
      _Brand(name: 'Comfy', color: Color(0xFF1675A6)),
      SizedBox(width: 9),
      _Brand(name: 'AURA', color: _purple),
    ],
  );
}

class _Brand extends StatelessWidget {
  const _Brand({required this.name, required this.color});
  final String name;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x0B000000), blurRadius: 12)],
      ),
      child: Text(
        name,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    ),
  );
}

class _SaleBanner extends StatelessWidget {
  const _SaleBanner();
  @override
  Widget build(BuildContext context) => Container(
    height: 88,
    padding: const EdgeInsets.symmetric(horizontal: 18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(
        colors: [Color(0xFFD9CDFF), Color(0xFFFFE3EF)],
      ),
    ),
    child: const Row(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Скидки до 30%',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
              Text(
                'На товары для малышей',
                style: TextStyle(fontSize: 12, color: _ink),
              ),
            ],
          ),
        ),
        Icon(Icons.toys_outlined, color: _purple, size: 52),
      ],
    ),
  );
}

class _Products extends StatelessWidget {
  const _Products({required this.provider});
  final MarketProvider provider;
  @override
  Widget build(BuildContext context) {
    final products = provider.filteredProducts.take(4).toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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
          borderRadius: BorderRadius.circular(18),
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
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEDEBF5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F1FA),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      size: 60,
                      color: _purple,
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${product.price.toStringAsFixed(0)} ₸',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: _ink,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => provider.addToCart(product),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _purple,
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
    );
  }
}
