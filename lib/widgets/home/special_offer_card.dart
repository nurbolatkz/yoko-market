import 'package:flutter/material.dart';

import '../../models/banner_item.dart';
import '../../theme/app_theme.dart';

/// «Специальные предложения» card: badge, title, subtitle, arrow button and
/// a product image on the right. Fed by banners with `placement: special`;
/// `image_url` should be a transparent product cut-out (see API_CONTRACT.md).
class SpecialOfferCard extends StatelessWidget {
  const SpecialOfferCard({super.key, required this.banner, required this.onTap});

  final BannerItem banner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badge = banner.discountBadge ?? banner.badge;
    final subtitle = banner.subtitle;
    return Semantics(
      button: true,
      label: banner.title,
      child: Material(
        color: AppColors.peachSoft,
        borderRadius: AppRadii.cardBorder,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (badge != null && badge.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: const BoxDecoration(
                            gradient: AppGradients.brand,
                            borderRadius: AppRadii.chipBorder,
                          ),
                          child: Text(
                            badge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.surface,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      Text(
                        banner.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 16,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.navyMuted,
                            fontSize: 12,
                            height: 1.25,
                          ),
                        ),
                      ],
                      const Spacer(),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        width: 40,
                        height: 32,
                        decoration: const BoxDecoration(
                          gradient: AppGradients.brand,
                          borderRadius: AppRadii.chipBorder,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.surface,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                if (banner.imageUrl != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    flex: 4,
                    child: LayoutBuilder(
                      builder: (context, c) => Image.network(
                        banner.imageUrl!,
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomRight,
                        cacheWidth: (c.maxWidth *
                                MediaQuery.devicePixelRatioOf(context))
                            .ceil()
                            .clamp(128, 800),
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
