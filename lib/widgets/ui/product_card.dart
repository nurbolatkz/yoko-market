import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../product_image.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.name,
    required this.price,
    this.regularPrice,
    this.imageUrl,
    this.size,
    this.meta,
    this.onTap,
    this.onAddToCart,
    this.isInCart = false,
  });

  final String name;
  final int price;
  final int? regularPrice;
  final String? imageUrl;
  final String? size;
  final String? meta;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final bool isInCart;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.cardBorder,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadii.card),
              ),
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  color: AppColors.purpleSoft,
                  child: imageUrl != null && imageUrl!.isNotEmpty
                      ? ProductImage(imageUrl: imageUrl!)
                      : const ProductImagePlaceholder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'NunitoSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  if (meta != null || size != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      [if (size != null) size!, if (meta != null) meta!]
                          .join(' · '),
                      style: const TextStyle(
                        fontFamily: 'NunitoSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.navyMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatMoney(price),
                            style: const TextStyle(
                              fontFamily: 'NunitoSans',
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                            ),
                          ),
                          if (regularPrice != null && regularPrice! > price)
                            Text(
                              formatMoney(regularPrice!),
                              style: const TextStyle(
                                fontFamily: 'NunitoSans',
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: AppColors.navyMuted,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),
                      _AddButton(isInCart: isInCart, onTap: onAddToCart),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({this.onTap, this.isInCart = false});

  final VoidCallback? onTap;
  final bool isInCart;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isInCart ? AppColors.purple : AppColors.purpleSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          isInCart ? Icons.check : Icons.add,
          size: 20,
          color: isInCart ? Colors.white : AppColors.purple,
        ),
      ),
    );
  }
}
