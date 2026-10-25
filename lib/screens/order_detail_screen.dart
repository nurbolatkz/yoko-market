import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/app_button.dart';
import 'reorder_screen.dart';

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '№ ${order.orderNumber}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          // Status + date
          _InfoCard(
            children: [
              Row(
                children: [
                  const Text(
                    'Статус',
                    style: TextStyle(color: AppColors.navyMuted, fontSize: 14),
                  ),
                  const Spacer(),
                  _StatusChip(
                      status: order.status, label: order.statusLabel),
                ],
              ),
              const SizedBox(height: 12),
              _DetailRow(label: 'Дата заказа', value: _fmtDate(order.createdAt)),
            ],
          ),
          const SizedBox(height: 16),

          // Items
          _SectionLabel(title: 'Товары (${order.items.length})'),
          const SizedBox(height: 8),
          _InfoCard(
            children: [
              for (int i = 0; i < order.items.length; i++) ...[
                if (i > 0)
                  const Divider(
                      height: 1,
                      indent: 0,
                      color: AppColors.border),
                _ItemRow(item: order.items[i]),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Payment breakdown
          _SectionLabel(title: 'Расчёт'),
          const SizedBox(height: 8),
          _InfoCard(
            children: [
              _DetailRow(
                label: 'Товары',
                value: '${_fmt(order.items.fold(0, (s, i) => s + i.lineTotal))} ₸',
              ),
              if (order.promoDiscount > 0) ...[
                const SizedBox(height: 8),
                _DetailRow(
                  label: 'Промокод${order.promoCodeUsed != null ? ' (${order.promoCodeUsed})' : ''}',
                  value: '−${_fmt(order.promoDiscount)} ₸',
                  valueColor: const Color(0xFF23804A),
                ),
              ],
              if (order.bonusUsed > 0) ...[
                const SizedBox(height: 8),
                _DetailRow(
                  label: 'Бонусы',
                  value: '−${_fmt(order.bonusUsed)} ₸',
                  valueColor: const Color(0xFF23804A),
                ),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Итого',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(
                    '${_fmt(order.totalAmount)} ₸',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Delivery address
          _SectionLabel(title: 'Доставка'),
          const SizedBox(height: 8),
          _InfoCard(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 18, color: AppColors.navyMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      order.address,
                      style: const TextStyle(
                          color: AppColors.navy, fontSize: 14, height: 1.4),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Reorder — visible for completed orders
          if (order.status == 'delivered' || order.status == 'cancelled') ...[
            const SizedBox(height: 24),
            AppButton(
              label: 'Повторить заказ',
              icon: const Icon(Icons.replay_rounded, size: 18),
              fullWidth: true,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReorderScreen(order: order),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Status chip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.label});
  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = _color(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  static Color _color(String status) => switch (status) {
        'delivered' => const Color(0xFF23804A),
        'cancelled' => const Color(0xFFD32F2F),
        'shipped' || 'confirmed' || 'payment_received' => AppColors.purple,
        _ => AppColors.navyMuted,
      };
}

String _fmt(int amount) => amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );

String _fmtDate(DateTime dt) {
  final local = dt.toLocal();
  final months = [
    'янв', 'фев', 'мар', 'апр', 'май', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
  ];
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.navyMuted,
            letterSpacing: .3,
          ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardBorder,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor = AppColors.navy,
  });
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.navyMuted, fontSize: 14),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
              color: valueColor, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});
  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.qty} × ${_fmt(item.unitPrice)} ₸',
                style: const TextStyle(
                    color: AppColors.navyMuted, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                '${_fmt(item.lineTotal)} ₸',
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
