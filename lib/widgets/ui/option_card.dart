import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.selected,
    required this.onTap,
    this.useCheckbox = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool selected;
  final VoidCallback onTap;
  final bool useCheckbox;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.cardBorder,
          border: Border.all(
            color: selected ? AppColors.purple : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'NunitoSans',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.purple : AppColors.navy,
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
                  if (trailing != null) ...[
                    const SizedBox(height: 4),
                    trailing!,
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            if (useCheckbox)
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color:
                      selected ? AppColors.purple : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: selected
                        ? AppColors.purple
                        : AppColors.navyMuted,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check,
                        size: 14, color: Colors.white)
                    : null,
              )
            else
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? AppColors.purple
                        : AppColors.navyMuted,
                    width: selected ? 6 : 1.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
