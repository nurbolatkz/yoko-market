import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.purple : AppColors.surface,
          borderRadius: AppRadii.chipBorder,
          border: Border.all(
            color: selected ? AppColors.purple : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'NunitoSans',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.navy,
          ),
        ),
      ),
    );
  }
}

class ChipGroup extends StatelessWidget {
  const ChipGroup({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    this.padding,
  });

  final List<String> items;
  final String? selected;
  final ValueChanged<String> onSelected;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Row(
        children: items.asMap().entries.map((e) {
          return Padding(
            padding:
                EdgeInsets.only(right: e.key < items.length - 1 ? 8 : 0),
            child: AppChip(
              label: e.value,
              selected: e.value == selected,
              onTap: () => onSelected(e.value),
            ),
          );
        }).toList(),
      ),
    );
  }
}
