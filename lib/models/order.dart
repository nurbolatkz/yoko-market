import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class OrderItem {
  const OrderItem({
    required this.name,
    required this.qty,
    required this.unitPrice,
    this.productId,
  });

  final String name;
  final int qty;
  final int unitPrice;
  // Populated from the backend JSONB field `product_id` (present since checkout
  // service v2). Null for orders created before that field was added.
  final String? productId;

  int get lineTotal => unitPrice * qty;

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        name: j['name'] as String,
        qty: (j['qty'] as num).toInt(),
        unitPrice: (j['price'] as num).toInt(),
        productId: j['product_id'] as String?,
      );
}

class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.totalAmount,
    required this.items,
    required this.address,
    required this.createdAt,
    this.promoCodeUsed,
    required this.promoDiscount,
    required this.bonusUsed,
  });

  final String id;
  final String orderNumber;
  final String status;
  final int totalAmount;
  final List<OrderItem> items;
  final String address;
  final DateTime createdAt;
  final String? promoCodeUsed;
  final int promoDiscount;
  final int bonusUsed;

  String get statusLabel => switch (status) {
        'pending_payment' => 'Ожидает оплаты',
        'payment_received' => 'Оплата получена',
        'confirmed' => 'Подтверждён',
        'shipped' => 'В доставке',
        'delivered' => 'Доставлен',
        'cancelled' => 'Отменён',
        _ => status,
      };

  Color get statusColor => switch (status) {
        'delivered' => const Color(0xFF23804A),
        'cancelled' => const Color(0xFFD32F2F),
        'shipped' => AppColors.purple,
        'confirmed' => AppColors.purple,
        'payment_received' => AppColors.purple,
        _ => AppColors.navyMuted,
      };

  factory OrderSummary.fromJson(Map<String, dynamic> j) => OrderSummary(
        id: j['id'] as String,
        orderNumber: j['order_number'] as String,
        status: j['status'] as String,
        totalAmount: (j['total_amount'] as num).toInt(),
        items: (j['items'] as List<dynamic>)
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        address: j['address'] as String? ?? '',
        createdAt: DateTime.parse(j['created_at'] as String),
        promoCodeUsed: j['promo_code_used'] as String?,
        promoDiscount: (j['promo_discount'] as num?)?.toInt() ?? 0,
        bonusUsed: (j['bonus_used'] as num?)?.toInt() ?? 0,
      );
}
