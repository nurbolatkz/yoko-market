import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../providers/auth_provider.dart';
import '../providers/orders_provider.dart';
import '../theme/app_theme.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    context.read<OrdersProvider>().fetchOrders(auth);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<OrdersProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Мои заказы',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _buildBody(context, prov, auth),
    );
  }

  Widget _buildBody(
      BuildContext context, OrdersProvider prov, AuthProvider auth) {
    if (!auth.isAuthenticated) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Войдите в аккаунт, чтобы видеть заказы',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.navyMuted, fontSize: 15),
          ),
        ),
      );
    }

    if (prov.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (prov.error == 'auth') {
      return _ErrorView(
        message: 'Сессия истекла. Войдите снова.',
        onRetry: null,
      );
    }

    if (prov.error != null) {
      return _ErrorView(message: prov.error!, onRetry: _load);
    }

    if (prov.orders.isEmpty) {
      return _EmptyView(onBrowse: () => Navigator.pop(context));
    }

    return RefreshIndicator(
      onRefresh: () =>
          context.read<OrdersProvider>().fetchOrders(context.read<AuthProvider>()),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: prov.orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final order = prov.orders[i];
          return _OrderCard(
            order: order,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderDetailScreen(order: order),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Order card ────────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});
  final OrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.cardBorder,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.cardBorder,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '№ ${order.orderNumber}',
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                _StatusChip(status: order.status, label: order.statusLabel),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _fmtDate(order.createdAt),
              style: const TextStyle(
                color: AppColors.navyMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '${order.items.length} '
                  '${_itemWord(order.items.length)}',
                  style: const TextStyle(
                    color: AppColors.navyMuted,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_fmt(order.totalAmount)} ₸',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
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

// ── Empty / error views ───────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onBrowse});
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 72,
              color: AppColors.purple,
            ),
            const SizedBox(height: 16),
            Text(
              'Заказов пока нет',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ваши заказы появятся здесь',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.navyMuted),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onBrowse,
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('За покупками'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 52, color: AppColors.purple),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Повторить'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Formatters ────────────────────────────────────────────────────────────────

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

String _itemWord(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 19) return 'товаров';
  if (mod10 == 1) return 'товар';
  if (mod10 >= 2 && mod10 <= 4) return 'товара';
  return 'товаров';
}
