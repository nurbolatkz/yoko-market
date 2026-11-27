import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../product_image.dart';

/// Unified 2-column grid card used by the Home "Популярные товары" grid
/// and the Catalog grid.
///
/// [imageKeyPrefix] must be set by the caller ('home' or 'catalog') so
/// integration tests can locate the ProductImage by screen.
class AppProductCard extends StatelessWidget {
  const AppProductCard({
    super.key,
    required this.product,
    required this.cartQty,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
    this.onAdd,
    required this.onDecrement,
    this.onIncrement,
    required this.imageKeyPrefix,
  });

  final Product product;
  final int cartQty;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback? onAdd;
  final VoidCallback onDecrement;
  final VoidCallback? onIncrement;
  final String imageKeyPrefix;

  @override
  Widget build(BuildContext context) {
    final canAdd = onAdd != null;
    final hasDiscount = product.originalPrice != null &&
        product.originalPrice! > product.price;
    final discPct = hasDiscount
        ? ((1 - product.price / product.originalPrice!) * 100).round()
        : 0;

    return InkWell(
      borderRadius: AppRadii.cardBorder,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.cardBorder,
          boxShadow: [
            BoxShadow(
              color: AppColors.brandOrange.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Photo + badges ────────────────────────────────────────
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ProductImage(
                        key: Key('$imageKeyPrefix-product-image-${product.id}'),
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
                            horizontal: 6, vertical: 2),
                        decoration: const BoxDecoration(
                          gradient: AppGradients.brand,
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        child: Text(
                          '-$discPct%',
                          style: const TextStyle(
                            color: AppColors.surface,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Semantics(
                      button: true,
                      label: isFavorite
                          ? 'Убрать из избранного'
                          : 'В избранное',
                      child: GestureDetector(
                        onTap: onFavorite,
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(
                            isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 22,
                            color: isFavorite
                                ? AppColors.brandRed
                                : AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // ── Name ───────────────────────────────────────────────────
            Text(
              product.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            // ── Packaging ──────────────────────────────────────────────
            if (product.packageInfo.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                product.packageInfo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.navyMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const Spacer(),
            // ── Price + Add / Stepper ──────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasDiscount)
                        Text(
                          formatMoney(product.originalPrice!.round()),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.navyMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formatMoney(product.price.round()),
                          maxLines: 1,
                          style: TextStyle(
                            color: hasDiscount
                                ? AppColors.brandRed
                                : AppColors.ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                cartQty > 0
                    ? _CardStepper(
                        qty: cartQty,
                        canIncrement: onIncrement != null,
                        onDecrement: onDecrement,
                        onIncrement: onIncrement,
                      )
                    : _CardAddButton(
                        key: Key('add-${product.id}'),
                        canAdd: canAdd,
                        onTap: onAdd,
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stepper ────────────────────────────────────────────────────────────────────

class _CardStepper extends StatelessWidget {
  const _CardStepper({
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
        color: AppColors.peachSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CardStepBtn(icon: Icons.remove, onTap: onDecrement, active: true),
          SizedBox(
            width: 26,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.brandRed,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _CardStepBtn(
            icon: Icons.add,
            onTap: onIncrement,
            active: canIncrement,
          ),
        ],
      ),
    );
  }
}

class _CardStepBtn extends StatelessWidget {
  const _CardStepBtn({
    required this.icon,
    required this.onTap,
    required this.active,
  });

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
          color: active ? AppColors.brandRed : AppColors.border,
        ),
      ),
    );
  }
}

// ── Add button (with spring press animation) ───────────────────────────────────

class _CardAddButton extends StatefulWidget {
  const _CardAddButton({super.key, required this.canAdd, this.onTap});

  final bool canAdd;
  final VoidCallback? onTap;

  @override
  State<_CardAddButton> createState() => _CardAddButtonState();
}

class _CardAddButtonState extends State<_CardAddButton> {
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
        child: Semantics(
          button: true,
          enabled: widget.canAdd,
          label: 'В корзину',
          child: Container(
            width: 44,
            height: 36,
            decoration: BoxDecoration(
              gradient: widget.canAdd ? AppGradients.brand : null,
              color: widget.canAdd ? null : AppColors.border,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.shopping_cart_outlined,
              size: 20,
              color: widget.canAdd ? AppColors.surface : AppColors.navyMuted,
            ),
          ),
        ),
      ),
    );
  }
}
