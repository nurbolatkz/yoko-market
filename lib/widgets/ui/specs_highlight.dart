import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SpecHighlightItem {
  const SpecHighlightItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;
}

class SpecsHighlight extends StatelessWidget {
  const SpecsHighlight({super.key, required this.items});

  final List<SpecHighlightItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(child: _SpecCard(item: items[i])),
        ],
      ],
    );
  }
}

class _SpecCard extends StatelessWidget {
  const _SpecCard({required this.item});

  final SpecHighlightItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardBorder,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, size: 24, color: AppColors.purple),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.value,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: const TextStyle(
              color: AppColors.navyMuted,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
