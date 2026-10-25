import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class NavRow extends StatelessWidget {
  const NavRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.cardBorder,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontFamily: 'NunitoSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.navyMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text(
              '›',
              style: TextStyle(
                fontFamily: 'NunitoSans',
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.purple,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
