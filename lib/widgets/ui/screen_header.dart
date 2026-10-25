import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.backLabel,
    this.onBack,
    this.actions,
    this.bottom,
  });

  final String title;
  final String? backLabel;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onBack != null) ...[
            GestureDetector(
              onTap: onBack,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.arrow_back_ios_rounded,
                      size: 14,
                      color: AppColors.purple,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      backLabel ?? 'Назад',
                      style: const TextStyle(
                        fontFamily: 'NunitoSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.purple,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'NunitoSans',
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ),
              ...?actions,
            ],
          ),
          if (bottom != null) ...[
            const SizedBox(height: AppSpacing.sm),
            bottom!,
          ],
        ],
      ),
    );
  }
}
