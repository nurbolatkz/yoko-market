import 'package:flutter/material.dart';

import '../../models/banner_item.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_image.dart';
import '../ui/skeleton.dart';

/// Banner proportions on Home. Backend banners are 1942×809 (≈2.4:1), so a
/// ready banner fits exactly and its baked-in text is never cropped.
const double kHeroBannerAspect = 2.4;

/// Home hero carousel (YO market design).
///
/// Two image formats, decided by [BannerItem.imageKind]:
/// - **ready** — the image already contains the text: shown whole
///   (`BoxFit.contain`), Flutter adds no text on top;
/// - **illustration** — an image without text: Flutter draws title, subtitle
///   and — only when the banner has a working action — a CTA in the free
///   left area, away from the faces on the right.
/// A banner without an image becomes a compact text card, never a large
/// empty fill.
class HomeHeroCarousel extends StatefulWidget {
  const HomeHeroCarousel({
    super.key,
    required this.banners,
    required this.onOpen,
    required this.onAction,
  });

  final List<BannerItem> banners;

  /// Tap on the banner itself → banner details.
  final ValueChanged<BannerItem> onOpen;

  /// CTA of an illustration banner → its category / product.
  final ValueChanged<BannerItem> onAction;

  @override
  State<HomeHeroCarousel> createState() => _HomeHeroCarouselState();
}

class _HomeHeroCarouselState extends State<HomeHeroCarousel> {
  final _ctrl = PageController();
  int _current = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = widget.banners;
    if (banners.isEmpty) return const SizedBox.shrink();
    final allTextOnly = banners.every((b) => b.imageUrl == null);
    return LayoutBuilder(
      builder: (context, c) {
        // Illustration banners draw their copy in Flutter, so they grow with
        // the text scale; ready banners keep the image's own proportions.
        final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
        final grow = banners.any((b) => b.isIllustration)
            ? scale.clamp(1.0, 1.7)
            : 1.0;
        final height = allTextOnly
            ? _textCardHeight(context)
            : c.maxWidth / kHeroBannerAspect * grow;
        return Column(
          children: [
            SizedBox(
              height: height,
              child: PageView.builder(
                controller: _ctrl,
                itemCount: banners.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (context, i) => Padding(
                  padding: EdgeInsets.only(
                    right: i < banners.length - 1 ? AppSpacing.sm : 0,
                  ),
                  child: _HeroCard(
                    banner: banners[i],
                    onOpen: () => widget.onOpen(banners[i]),
                    onAction: () => widget.onAction(banners[i]),
                  ),
                ),
              ),
            ),
            if (banners.length > 1) ...[
              const SizedBox(height: AppSpacing.sm),
              _Dots(count: banners.length, current: _current),
            ],
          ],
        );
      },
    );
  }

  double _textCardHeight(BuildContext context) =>
      96 + (MediaQuery.textScalerOf(context).scale(16) - 16) * 3;
}

/// Loading placeholder with the banner's final proportions (no jump).
class HomeHeroSkeleton extends StatelessWidget {
  const HomeHeroSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const AspectRatio(
      aspectRatio: kHeroBannerAspect,
      child: Skeleton(height: double.infinity, radius: AppRadii.card),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.banner,
    required this.onOpen,
    required this.onAction,
  });

  final BannerItem banner;
  final VoidCallback onOpen;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final url = banner.imageUrl;
    final Widget child;
    if (url == null) {
      child = _TextCard(banner: banner);
    } else if (banner.isIllustration) {
      child = _IllustrationCard(banner: banner, url: url, onAction: onAction);
    } else {
      child = _ReadyImage(banner: banner, url: url);
    }
    return Semantics(
      button: true,
      label: banner.title,
      child: GestureDetector(
        onTap: onOpen,
        child: ClipRRect(borderRadius: AppRadii.cardBorder, child: child),
      ),
    );
  }
}

/// Finished banner with baked-in text: whole image, nothing drawn on top.
class _ReadyImage extends StatelessWidget {
  const _ReadyImage({required this.banner, required this.url});

  final BannerItem banner;
  final String url;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final px = (c.maxWidth * MediaQuery.devicePixelRatioOf(context))
            .ceil()
            .clamp(600, 2048);
        return ColoredBox(
          color: AppColors.peachSoft,
          child: Image(
            image: appImageProviderSized(url, px),
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            semanticLabel: banner.title,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Skeleton(height: double.infinity, radius: 0),
            errorBuilder: (_, _, _) => _TextCard(banner: banner),
          ),
        );
      },
    );
  }
}

/// Image without text: Flutter draws the copy on the left free area.
class _IllustrationCard extends StatelessWidget {
  const _IllustrationCard({
    required this.banner,
    required this.url,
    required this.onAction,
  });

  final BannerItem banner;
  final String url;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final subtitle = banner.subtitle;
    final largeText = MediaQuery.textScalerOf(context).scale(10) > 13;
    return LayoutBuilder(
      builder: (context, c) {
        final px = (c.maxWidth * MediaQuery.devicePixelRatioOf(context))
            .ceil()
            .clamp(600, 2048);
        return Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: appImageProviderSized(url, px),
              fit: BoxFit.cover,
              // Faces sit on the right of the illustration — keep them.
              alignment: Alignment.centerRight,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: AppColors.peachSoft),
            ),
            // Soft wash behind the copy only; the right side stays clear.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.peachTop,
                    AppColors.peachTop.withValues(alpha: 0),
                  ],
                  stops: const [0.25, 0.62],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              child: FractionallySizedBox(
                widthFactor: 0.56,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        banner.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 19,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: largeText ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
                    ],
                    if (banner.hasAction) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _Cta(
                        label: banner.actionLabel?.isNotEmpty == true
                            ? banner.actionLabel!
                            : (banner.actionType == 'product'
                                  ? 'Смотреть товар'
                                  : 'К покупкам'),
                        onTap: onAction,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Cta extends StatelessWidget {
  const _Cta({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: const BoxDecoration(
            gradient: AppGradients.brand,
            borderRadius: AppRadii.chipBorder,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.surface,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.surface,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// No image (or the image failed): compact soft card, never a large fill.
class _TextCard extends StatelessWidget {
  const _TextCard({required this.banner});

  final BannerItem banner;

  @override
  Widget build(BuildContext context) {
    final subtitle = banner.subtitle;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.surface, AppColors.peachSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    banner.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navyMuted,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.brandRed),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: i == current ? 16 : 6,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              decoration: BoxDecoration(
                color: i == current ? AppColors.brandRed : AppColors.peachTop,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
        ],
      ),
    );
  }
}
