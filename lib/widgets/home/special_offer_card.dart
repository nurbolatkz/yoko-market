import 'package:flutter/material.dart';

import '../../models/banner_item.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_image.dart';

/// «Специальные предложения» card (YO market design): badge and copy on top,
/// arrow bottom-left, illustration bottom-right.
///
/// Fed by banners with `placement: special` — a proposed field that the
/// backend does not serve yet, so production hides the block. The picture is
/// [BannerItem.illustrationUrl], a transparent cut-out kept separate from the
/// banner's `image_url`.
class SpecialOfferCard extends StatelessWidget {
  const SpecialOfferCard({
    super.key,
    required this.banner,
    required this.onTap,
  });

  final BannerItem banner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badge = banner.discountBadge ?? banner.badge;
    final subtitle = banner.subtitle;
    final illustration = banner.illustrationUrl;
    // No LayoutBuilder: the cards sit in an IntrinsicHeight row.
    final cachePx =
        (MediaQuery.sizeOf(context).width *
                0.3 *
                MediaQuery.devicePixelRatioOf(context))
            .ceil()
            .clamp(128, 800);
    return Semantics(
      button: true,
      label: [banner.title, ?badge].join('. '),
      excludeSemantics: true,
      child: Material(
        color: AppColors.peachSoft,
        borderRadius: AppRadii.cardBorder,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              if (illustration != null)
                Positioned(
                  right: 0,
                  bottom: 0,
                  width: MediaQuery.sizeOf(context).width * 0.22,
                  height: 92,
                  child: Image(
                    image: appImageProviderSized(illustration, cachePx),
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomRight,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
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
                        fontSize: 15,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      FractionallySizedBox(
                        widthFactor: illustration != null ? 0.7 : 1,
                        child: Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.navyMuted,
                            fontSize: 12,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                    // Room for the illustration under the copy.
                    SizedBox(height: illustration != null ? 56 : AppSpacing.md),
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
            ],
          ),
        ),
      ),
    );
  }
}
