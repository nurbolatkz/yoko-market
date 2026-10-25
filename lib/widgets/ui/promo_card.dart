import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class PromoCard extends StatelessWidget {
  const PromoCard({
    super.key,
    required this.title,
    required this.body,
    this.onTap,
    this.backgroundColor,
    this.leading,
  });

  final String title;
  final String body;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.yellowSoft,
          borderRadius: AppRadii.cardBorder,
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'NunitoSans',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(
                      fontFamily: 'NunitoSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.navyMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppColors.navyMuted,
            ),
          ],
        ),
      ),
    );
  }
}
