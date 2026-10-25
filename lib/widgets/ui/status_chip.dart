import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

enum OrderStatusVariant { pending, confirmed, shipped, delivered, cancelled }

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final OrderStatusVariant status;

  static OrderStatusVariant fromString(String s) {
    switch (s) {
      case 'pending_payment':
      case 'payment_received':
        return OrderStatusVariant.pending;
      case 'confirmed':
        return OrderStatusVariant.confirmed;
      case 'shipped':
        return OrderStatusVariant.shipped;
      case 'delivered':
        return OrderStatusVariant.delivered;
      case 'cancelled':
        return OrderStatusVariant.cancelled;
      default:
        return OrderStatusVariant.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = _resolve();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'NunitoSans',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  (String, Color, Color) _resolve() {
    switch (status) {
      case OrderStatusVariant.pending:
        return ('Ожидает оплаты', AppColors.purpleSoft, AppColors.purple);
      case OrderStatusVariant.confirmed:
        return ('Подтверждён', AppColors.purpleSoft, AppColors.purpleDark);
      case OrderStatusVariant.shipped:
        return (
          'В пути',
          const Color(0xFFE8F5E9),
          const Color(0xFF2E7D32)
        );
      case OrderStatusVariant.delivered:
        return ('Доставлен', const Color(0xFFE8F5E9), AppColors.success);
      case OrderStatusVariant.cancelled:
        return ('Отменён', AppColors.border, AppColors.navyMuted);
    }
  }
}
