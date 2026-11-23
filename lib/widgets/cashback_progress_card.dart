import 'package:flutter/material.dart';

import '../models/loyalty.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'ui/app_card.dart';
import 'ui/progress_card.dart';

/// «Кэшбэк в ноябре: 3 % · ещё 37 500 ₸ до 5 %» with a progress bar and the
/// preliminary YoCoin amount. Every number comes from [MonthlyCashback]
/// (server-computed) — nothing is calculated here.
class CashbackProgressCard extends StatelessWidget {
  const CashbackProgressCard({super.key, required this.cashback});

  final MonthlyCashback cashback;

  @override
  Widget build(BuildContext context) {
    final c = cashback;
    // monthLabel is nominative («Ноябрь») → «Кэшбэк за ноябрь».
    final month = c.monthLabel.isEmpty ? 'этот месяц' : c.monthLabel.toLowerCase();
    final days = '${c.daysLeft} ${pluralRu(c.daysLeft, 'день', 'дня', 'дней')}';

    final String subtitle;
    if (c.isTopTier) {
      subtitle = 'Максимальный кэшбэк — осталось $days';
    } else if (c.currentPercent == 0) {
      subtitle = 'Купите ещё на ${formatMoney(c.leftToNext)} — '
          'получите ${c.nextPercent}% · осталось $days';
    } else {
      subtitle = 'Ещё ${formatMoney(c.leftToNext)} до ${c.nextPercent}% · '
          'осталось $days';
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProgressCard(
            title: 'Кэшбэк за $month: ${c.currentPercent}%',
            subtitle: subtitle,
            progress: c.progress,
            startLabel: 'Куплено на ${formatMoney(c.monthSpent)}',
            endLabel: c.nextThreshold != null
                ? formatMoney(c.nextThreshold!)
                : null,
          ),
          if (c.previewAmount > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: const BoxDecoration(
                color: AppColors.yellowSoft,
                borderRadius: AppRadii.chipBorder,
              ),
              child: Text(
                'Предварительно: ~${formatNumber(c.previewAmount)} YoCoin '
                'после окончания месяца',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
