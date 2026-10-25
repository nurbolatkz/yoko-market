import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'app_button.dart';

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.message,
    required this.onRetry,
    this.onBack,
  });

  final String? message;
  final VoidCallback onRetry;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenH,
        vertical: AppSpacing.x3l,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 56, color: AppColors.navyMuted),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Не удалось загрузить',
            style: TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              message!,
              style: const TextStyle(
                fontFamily: 'NunitoSans',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.navyMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.x2l),
          AppButton(label: 'Повторить', onPressed: onRetry),
          if (onBack != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Вернуться назад',
              onPressed: onBack,
              variant: AppButtonVariant.secondary,
            ),
          ],
        ],
      ),
    );
  }
}
