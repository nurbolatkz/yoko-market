import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../theme/app_theme.dart';
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
                      onTap: onFavorite,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(220),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 16,
                          color: isFavorite
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
            // ── Price ──────────────────────────────────────────────────
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
            // ── Name ───────────────────────────────────────────────────
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
            // ── Packaging ──────────────────────────────────────────────
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
            // ── Add / Stepper ──────────────────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: cartQty > 0
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
        color: AppColors.purpleSoft,
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
                color: AppColors.purple,
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
          color: active ? AppColors.purple : AppColors.border,
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
            color: widget.canAdd ? Colors.white : AppColors.navyMuted,
          ),
        ),
      ),
    );
  }
}
