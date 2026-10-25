import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class HeroBalanceCard extends StatelessWidget {
  const HeroBalanceCard({
    super.key,
    required this.topLabel,
    required this.value,
    this.unit,
    this.subtitle,
    this.extra,
    this.gradient,
  });

  final String topLabel;
  final String value;
  final String? unit;
  final String? subtitle;
  final Widget? extra;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: gradient ??
            const LinearGradient(
              colors: [AppColors.purple, AppColors.purpleDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
        borderRadius: AppRadii.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            topLabel.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    unit!,
                    style: const TextStyle(
                      fontFamily: 'NunitoSans',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                fontFamily: 'NunitoSans',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colors.white70,
              ),
            ),
          ],
          if (extra != null) ...[
            const SizedBox(height: AppSpacing.lg),
            extra!,
          ],
        ],
      ),
    );
  }
}
