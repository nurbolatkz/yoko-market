import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class StepHeader extends StatelessWidget {
  const StepHeader({
    super.key,
    required this.current,
    required this.total,
    this.label,
  });

  final int current;
  final int total;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label ?? 'Шаг $current из $total',
          style: const TextStyle(
            fontFamily: 'NunitoSans',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.navyMuted,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Row(
            children: List.generate(total, (i) {
              return Expanded(
                child: Container(
                  height: 4,
                  margin:
                      EdgeInsets.only(right: i < total - 1 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: i < current
                        ? AppColors.purple
                        : AppColors.purpleSoft,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
