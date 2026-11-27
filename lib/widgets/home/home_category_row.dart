import 'package:flutter/material.dart';

import '../../models/product_category.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_image.dart';

/// Home categories: up to 4 photo tiles + «Все категории» (client mockup).
class HomeCategoryRow extends StatelessWidget {
  const HomeCategoryRow({
    super.key,
    required this.categories,
    required this.onSelected,
    required this.onSeeAll,
  });

  static const maxTiles = 4;

  final List<ProductCategory> categories;
  final ValueChanged<String> onSelected;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    final visible = categories.take(maxTiles).toList();
    final tiles = <Widget>[
      for (final cat in visible)
        _Tile(
          key: Key('home-category-${cat.name}'),
          label: cat.name,
          onTap: () => onSelected(cat.name),
          child: cat.imageUrl != null
              ? _CategoryImage(url: cat.imageUrl!)
              : const Icon(
                  Icons.category_outlined,
                  color: AppColors.navyMuted,
                  size: 28,
                ),
        ),
      _Tile(
        key: const Key('home-category-all'),
        label: 'Все категории',
        onTap: onSeeAll,
        child: const _AllCategoriesIcon(),
      ),
    ];
    const gap = AppSpacing.sm;
    return LayoutBuilder(
      builder: (context, constraints) {
        // A label line must fit «Подгузники» without breaking the word;
        // at large text sizes the row scrolls instead of squeezing.
        final scale = MediaQuery.textScalerOf(context).scale(11) / 11;
        final minTile = 66.0 * scale;
        final fitted =
            (constraints.maxWidth - gap * (tiles.length - 1)) / tiles.length;
        if (fitted >= minTile) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                Expanded(child: tiles[i]),
              ],
            ],
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                SizedBox(width: minTile, child: tiles[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                // White matches the white backdrop of the catalog photos.
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadii.imageBorder,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandOrange.withValues(alpha: 0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: child,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 11,
                height: 1.2,
                letterSpacing: -0.1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryImage extends StatelessWidget {
  const _CategoryImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    // Catalog photos are 602×602 on white with the product taking 67–87 %
    // of the frame and ≥6.8 % white margin on every side. A uniform 1.12
    // zoom trims only white margin, so every product keeps its full shape
    // and the tiles read at one visual scale.
    return LayoutBuilder(
      builder: (context, c) => Transform.scale(
        scale: 1.12,
        child: Image(
          image: appImageProviderSized(
            url,
            (c.maxWidth * MediaQuery.devicePixelRatioOf(context))
                .ceil()
                .clamp(64, 512),
          ),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => const Icon(
            Icons.category_outlined,
            color: AppColors.navyMuted,
            size: 28,
          ),
        ),
      ),
    );
  }
}

/// Four rounded squares in the brand gradient (mockup «Все категории»).
class _AllCategoriesIcon extends StatelessWidget {
  const _AllCategoriesIcon();

  @override
  Widget build(BuildContext context) {
    Widget square() => Container(
          decoration: const BoxDecoration(
            gradient: AppGradients.brand,
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
        );
    return FractionallySizedBox(
      widthFactor: 0.56,
      heightFactor: 0.56,
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [square(), square(), square(), square()],
      ),
    );
  }
}
