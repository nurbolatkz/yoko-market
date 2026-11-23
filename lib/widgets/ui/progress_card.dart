import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ProgressCard extends StatelessWidget {
  const ProgressCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.progress,
    this.startLabel,
    this.endLabel,
    this.progressLabel,
  });

  final String title;
  final String? subtitle;
  final double progress;
  final String? startLabel;
  final String? endLabel;
  final String? progressLabel;

  static const _labelStyle = TextStyle(
    fontFamily: 'NunitoSans',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.navyMuted,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
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
        const SizedBox(height: AppSpacing.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: AppColors.purpleSoft,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.purple),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: startLabel != null
                  ? Text(startLabel!, style: _labelStyle)
                  : const SizedBox.shrink(),
            ),
            if (progressLabel != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  progressLabel!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'NunitoSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.purple,
                  ),
                ),
              ),
            ],
            if (endLabel != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  endLabel!,
                  textAlign: TextAlign.end,
                  style: _labelStyle,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
