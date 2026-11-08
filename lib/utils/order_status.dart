import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

abstract final class OrderStatus {
  static String label(String status) => switch (status) {
        'pending_payment' => 'Ожидает оплаты',
        'payment_received' => 'Оплата получена',
        'confirmed' => 'Подтверждён',
        'shipped' => 'В пути',
        'delivered' => 'Доставлен',
        'cancelled' => 'Отменён',
        _ => status,
      };

  static Color color(String status) => switch (status) {
        'delivered' => AppColors.success,
        'cancelled' => AppColors.error,
        'shipped' || 'confirmed' || 'payment_received' => AppColors.purple,
        _ => AppColors.navyMuted,
      };

  static bool isActive(String status) =>
      status == 'pending_payment' ||
      status == 'payment_received' ||
      status == 'confirmed' ||
      status == 'shipped';

  static bool isCompleted(String status) =>
      status == 'delivered' || status == 'cancelled';

  /// Step in the 5-stage flow: 1=placed, 2=paid, 3=confirmed, 4=shipped,
  /// 5=delivered. Returns 0 for cancelled or unknown.
  static int step(String status) => switch (status) {
        'pending_payment' => 1,
        'payment_received' => 2,
        'confirmed' => 3,
        'shipped' => 4,
        'delivered' => 5,
        _ => 0,
      };
}
