import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SizeGuideSheet extends StatelessWidget {
  const SizeGuideSheet({super.key, this.specs});

  final Map<String, dynamic>? specs;

  static const _staticTable = <List<String>>[
    ['NB', 'до 5 кг'],
    ['S', '3–8 кг'],
    ['M', '6–11 кг'],
    ['L', '9–18 кг'],
    ['XL', '11–25 кг'],
    ['XXL', '13+ кг'],
  ];

  static const _sizeKeys = ['NB', 'S', 'M', 'L', 'XL', 'XXL'];

  List<List<String>> _buildRows() {
    final s = specs;
    if (s != null) {
      // Check if specs has a 'size_guide' key with a map
      final sizeGuide = s['size_guide'];
      if (sizeGuide is Map) {
        final rows = <List<String>>[];
        for (final key in _sizeKeys) {
          final val = sizeGuide[key];
          if (val != null) rows.add([key, '$val']);
        }
        if (rows.isNotEmpty) return rows;
      }
      // Check for direct weight-range keys
      final rows = <List<String>>[];
      for (final key in _sizeKeys) {
        final val = s[key];
        if (val != null) rows.add([key, '$val']);
      }
      if (rows.isNotEmpty) return rows;
    }
    return _staticTable;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _buildRows();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
              child: Row(
                children: [
                  Text(
                    'Таблица размеров',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            // Table
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.x2l),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadii.cardBorder,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    // Header row
                    Container(
                      decoration: const BoxDecoration(
                        color: AppColors.purpleSoft,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(AppRadii.card),
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Размер',
                                style: TextStyle(
                                  color: AppColors.navy,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Вес ребёнка',
                                style: TextStyle(
                                  color: AppColors.navy,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    for (int i = 0; i < rows.length; i++) ...[
                      const Divider(height: 1, color: AppColors.border),
                      Container(
                        color: i.isOdd
                            ? AppColors.purpleSoft.withValues(alpha: 0.4)
                            : AppColors.surface,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  rows[i][0],
                                  style: const TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  rows[i][1],
                                  style: const TextStyle(
                                    color: AppColors.navyMuted,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
