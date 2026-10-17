import 'package:flutter/material.dart';

import '../models/checkout_estimate.dart';
import '../theme/app_theme.dart';
import 'orders_screen.dart';

class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({
    super.key,
    required this.result,
    this.expectedTotal,
  });

  final PlaceOrderResult result;
  // The estimate's orderTotal at the moment the user tapped "place order".
  // Used to surface a server-adjusted price note in the UI.
  final int? expectedTotal;

  bool get _priceAdjusted =>
      expectedTotal != null && expectedTotal != result.total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF23804A),
                size: 80,
              ),
              const SizedBox(height: 24),
              Text(
                'Заказ оформлен',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '№ ${result.orderNumber}',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.navyMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadii.cardBorder,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_priceAdjusted) ...[
                      Row(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 14, color: AppColors.navyMuted),
                          const SizedBox(width: 6),
                          Text(
                            'Сумма уточнена сервером',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.navyMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'К оплате',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: AppColors.navyMuted),
                        ),
                        Text(
                          '${_fmt(result.total)} ₸',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              OutlinedButton(
                key: const Key('confirm-view-orders'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OrdersScreen()),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Посмотреть заказ',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                key: const Key('confirm-done'),
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Готово', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _fmt(int amount) => amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );
