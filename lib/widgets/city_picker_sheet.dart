import 'package:flutter/material.dart';

import '../models/checkout_estimate.dart';
import '../theme/app_theme.dart';

/// Bottom sheet with the serviced cities (`GET /checkout/cities`).
/// Resolves with the chosen city, or null when dismissed.
Future<BranchCity?> showCityPickerSheet(
  BuildContext context, {
  required List<BranchCity> cities,
  String? selectedCode,
}) {
  return showModalBottomSheet<BranchCity>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
    ),
    builder: (context) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.md, 0, AppSpacing.x3l),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.sm,
            AppSpacing.screenH,
            AppSpacing.xs,
          ),
          child: Text(
            'Город доставки',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            0,
            AppSpacing.screenH,
            AppSpacing.sm,
          ),
          child: Text(
            'От города зависят филиал, цены и наличие при оформлении заказа',
            style: TextStyle(color: AppColors.navyMuted, fontSize: 13),
          ),
        ),
        for (final city in cities)
          ListTile(
            minTileHeight: 48,
            title: Text(
              city.name,
              style: const TextStyle(color: AppColors.ink, fontSize: 15),
            ),
            trailing: city.code == selectedCode
                ? const Icon(Icons.check_rounded, color: AppColors.brandRed)
                : null,
            selected: city.code == selectedCode,
            onTap: () => Navigator.of(context).pop(city),
          ),
      ],
    ),
  );
}
