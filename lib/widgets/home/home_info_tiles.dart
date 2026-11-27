import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/format.dart';

/// «Бонусы за покупку · Кэшбэк до N%» and «Бесплатная доставка · от N ₸».
/// Numbers come from the API (loyalty rules / delivery settings); while they
/// are unknown the second line is simply omitted — nothing is hardcoded.
class HomeInfoTiles extends StatelessWidget {
  const HomeInfoTiles({
    super.key,
    required this.maxCashbackPercent,
    required this.freeDeliveryFrom,
    required this.onBonusTap,
    required this.onDeliveryTap,
  });

  final int? maxCashbackPercent;
  final int? freeDeliveryFrom;
  final VoidCallback onBonusTap;
  final VoidCallback onDeliveryTap;

  @override
  Widget build(BuildContext context) {
    final pct = maxCashbackPercent;
    final from = freeDeliveryFrom;
    final bonus = _InfoTile(
      key: const Key('home-info-bonus'),
      title: 'Бонусы за покупку',
      value: pct != null && pct > 0 ? 'Кэшбэк до $pct%' : null,
      icon: Icons.percent_rounded,
      onTap: onBonusTap,
    );
    final delivery = _InfoTile(
      key: const Key('home-info-delivery'),
      title: 'Бесплатная доставка',
      value: from != null && from > 0 ? 'от ${formatMoney(from)}' : null,
      icon: Icons.local_shipping_rounded,
      onTap: onDeliveryTap,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Side by side while «Бесплатная» fits on a line; stacked otherwise.
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final tileWidth = (constraints.maxWidth - AppSpacing.md) / 2;
        if (tileWidth < 150 * scale) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [bonus, const SizedBox(height: AppSpacing.md), delivery],
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
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
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
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
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
                    if (value != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        value!,
                        style: const TextStyle(
                          color: AppColors.brandRed,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  gradient: AppGradients.brand,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.surface, size: 19),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
