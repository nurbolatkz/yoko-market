import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/format.dart';

/// «Кэшбэк до N%» and «Бесплатная доставка» cards with the client's
/// illustrations on the right and the text on the left.
///
/// Numbers are shown only when confirmed by the backend; otherwise the
/// value line falls back to neutral text — nothing from the mockup is
/// hardcoded.
class HomeInfoTiles extends StatelessWidget {
  const HomeInfoTiles({
    super.key,
    required this.maxCashbackPercent,
    required this.freeDeliveryFrom,
    required this.onBonusTap,
    required this.onDeliveryTap,
  });

  /// Programme maximum (highest tier) from `/loyalty/rules`; null → no number.
  final int? maxCashbackPercent;

  /// Confirmed free-delivery threshold; null → no number.
  final int? freeDeliveryFrom;
  final VoidCallback onBonusTap;
  final VoidCallback onDeliveryTap;

  static const bonusAsset = 'assets/images/home/info_bonus_coupon.webp';
  static const deliveryAsset = 'assets/images/home/info_delivery_van.webp';

  @override
  Widget build(BuildContext context) {
    final pct = maxCashbackPercent;
    final from = freeDeliveryFrom;
    final bonus = _InfoTile(
      key: const Key('home-info-bonus'),
      title: 'Бонусы за покупку',
      value: pct != null && pct > 0 ? 'Кэшбэк до $pct%' : 'Кэшбэк YoCoin',
      asset: bonusAsset,
      onTap: onBonusTap,
    );
    final delivery = _InfoTile(
      key: const Key('home-info-delivery'),
      title: 'Бесплатная доставка',
      value: from != null && from > 0
          ? 'от ${formatMoney(from)}'
          : 'Условия доставки',
      asset: deliveryAsset,
      onTap: onDeliveryTap,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Side by side while the title fits beside the illustration;
        // stacked full-width cards at large text sizes.
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final tileWidth = (constraints.maxWidth - AppSpacing.md) / 2;
        if (tileWidth < 160 * scale) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              bonus,
              const SizedBox(height: AppSpacing.sm),
              delivery,
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: bonus),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: delivery),
            ],
          ),
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    super.key,
    required this.title,
    required this.value,
    required this.asset,
    required this.onTap,
  });

  final String title;
  final String value;
  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $value',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadii.cardBorder,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.surface, AppColors.peachSoft],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 76),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        2,
                        AppSpacing.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 14,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            value,
                            style: const TextStyle(
                              color: AppColors.brandRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Illustration keeps its proportions and transparency.
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Image.asset(
                      asset,
                      width: 52,
                      height: 50,
                      fit: BoxFit.contain,
                      alignment: Alignment.centerRight,
                      excludeFromSemantics: true,
                      errorBuilder: (_, _, _) => const SizedBox(width: 52),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
