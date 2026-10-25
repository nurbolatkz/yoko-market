import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'app_button.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.title,
    required this.headline,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.bottom,
    this.icon,
  });

  final String? title;
  final String headline;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? bottom;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenH,
        vertical: AppSpacing.x3l,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(
                fontFamily: 'NunitoSans',
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: AppSpacing.x3l),
          ],
          if (icon != null) ...[
            Center(child: icon!),
            const SizedBox(height: AppSpacing.xl),
          ],
          Text(
            headline,
            style: const TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: const TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AppColors.navyMuted,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.x2l),
            AppButton(label: actionLabel!, onPressed: onAction),
          ],
          if (bottom != null) ...[
            const SizedBox(height: AppSpacing.x3l),
            bottom!,
          ],
        ],
      ),
    );
  }
}
