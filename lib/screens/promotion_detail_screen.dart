import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Stub — full implementation in feature/promotion-detail.
class PromotionDetailScreen extends StatelessWidget {
  const PromotionDetailScreen({super.key, required this.bannerId});

  final String bannerId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Акция'),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
