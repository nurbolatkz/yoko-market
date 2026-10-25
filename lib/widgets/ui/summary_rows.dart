import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';

class SummaryRow {
  const SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool isTotal;
  final Color? valueColor;
}

class SummaryRows extends StatelessWidget {
  const SummaryRows({super.key, required this.rows});

  final List<SummaryRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: rows.asMap().entries.map((e) {
        final row = e.value;
        return Padding(
          padding: EdgeInsets.only(top: e.key == 0 ? 0 : AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                row.label,
                style: TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: row.isTotal ? 16 : 14,
                  fontWeight:
                      row.isTotal ? FontWeight.w700 : FontWeight.w400,
                  color: row.isTotal ? AppColors.navy : AppColors.navyMuted,
                ),
              ),
              Text(
                row.value,
                style: TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: row.isTotal ? 18 : 14,
                  fontWeight:
                      row.isTotal ? FontWeight.w800 : FontWeight.w600,
                  color: row.valueColor ?? AppColors.navy,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

List<SummaryRow> buildOrderSummaryRows({
  required int subtotal,
  required int delivery,
  required int discount,
  required int bonusUsed,
  required int total,
}) {
  final rows = <SummaryRow>[];
  rows.add(SummaryRow(label: 'Товары', value: formatMoney(subtotal)));
  if (discount > 0) {
    rows.add(SummaryRow(
      label: 'Скидка по промокоду',
      value: '−${formatMoney(discount)}',
      valueColor: AppColors.success,
    ));
  }
  if (bonusUsed > 0) {
    rows.add(SummaryRow(
      label: 'Бонусы',
      value: '−${formatMoney(bonusUsed)}',
      valueColor: AppColors.purple,
    ));
  }
  rows.add(SummaryRow(
    label: 'Доставка',
    value: delivery == 0 ? 'Бесплатно' : formatMoney(delivery),
    valueColor: delivery == 0 ? AppColors.success : null,
  ));
  rows.add(SummaryRow(
    label: 'Итого',
    value: formatMoney(total),
    isTotal: true,
  ));
  return rows;
}
