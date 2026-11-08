import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../providers/auth_provider.dart';
import '../providers/orders_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/order_status.dart';
import '../widgets/ui/empty_state.dart';
import '../widgets/ui/error_state.dart';
import '../widgets/ui/skeleton.dart';
import '../widgets/ui/status_chip.dart';
import 'order_detail_screen.dart';
import 'reorder_screen.dart';

enum _Tab { all, active, completed }

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with WidgetsBindingObserver {
  _Tab _tab = _Tab.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final orders = context.read<OrdersProvider>().orders;
      if (orders.any((o) => OrderStatus.isActive(o.status))) _load();
    }
  }

  void _load() {
    if (!mounted) return;
    context
        .read<OrdersProvider>()
        .fetchOrders(context.read<AuthProvider>());
  }

  List<OrderSummary> _filtered(List<OrderSummary> orders) {
    return switch (_tab) {
      _Tab.all => orders,
      _Tab.active => orders.where((o) => OrderStatus.isActive(o.status)).toList(),
      _Tab.completed =>
        orders.where((o) => OrderStatus.isCompleted(o.status)).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<OrdersProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои заказы'),
      ),
      body: _buildBody(context, prov, auth),
    );
  }

  Widget _buildBody(
    BuildContext context,
    OrdersProvider prov,
    AuthProvider auth,
  ) {
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

    if (prov.error == 'auth') {
      return Center(
        child: ErrorState(
          message: 'Сессия истекла. Войдите снова.',
          onRetry: _load,
        ),
      );
    }

    if (prov.error != null) {
      return Center(
        child: ErrorState(message: prov.error, onRetry: _load),
      );
    }

    if (prov.loading && prov.orders.isEmpty) {
      return _buildSkeletonList();
    }

    final filtered = _filtered(prov.orders);

    return Column(
      children: [
        _TabBar(selected: _tab, onSelect: (t) => setState(() => _tab = t)),
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyTab(prov.orders.isEmpty)
              : RefreshIndicator(
                  onRefresh: () => prov.fetchOrders(
                    context.read<AuthProvider>(),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final order = filtered[i];
                      return _OrderCard(
                        order: order,
                        onTap: () => Navigator.push(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) => OrderDetailScreen(order: order),
                          ),
                        ),
                        onReorder: OrderStatus.isCompleted(order.status)
                            ? () => Navigator.push(
                                  ctx,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ReorderScreen(order: order),
                                  ),
                                )
                            : null,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyTab(bool allOrdersEmpty) {
    if (allOrdersEmpty) {
      return SingleChildScrollView(
        child: EmptyState(
          icon: const Icon(
            Icons.receipt_long_outlined,
            size: 56,
            color: AppColors.navyMuted,
          ),
          headline: 'Первая покупка впереди',
          body: 'Здесь появятся ваши заказы, статусы доставки и возможность повторить покупку.',
          actionLabel: 'Открыть каталог',
          onAction: () => Navigator.pop(context),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Нет заказов в этом разделе',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.navyMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return Column(
      children: [
        _TabBar(selected: _tab, onSelect: (_) {}),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, _) => _OrderCardSkeleton(),
          ),
        ),
      ],
    );
  }

}

// ── Tab bar ───────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  const _TabBar({required this.selected, required this.onSelect});

  final _Tab selected;
  final ValueChanged<_Tab> onSelect;

  static const _items = [
    (_Tab.all, 'Все'),
    (_Tab.active, 'Активные'),
    (_Tab.completed, 'Завершённые'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: _items.map((item) {
            final (tab, label) = item;
            final active = selected == tab;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onSelect(tab),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? AppColors.purple : AppColors.purpleSoft,
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'NunitoSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : AppColors.purple,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Order card ────────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onTap,
    this.onReorder,
  });

  final OrderSummary order;
  final VoidCallback onTap;
  final VoidCallback? onReorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPending = order.status == 'pending_payment';

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.cardBorder,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.cardBorder,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: order number + status chip + arrow
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
                const SizedBox(width: 8),
                StatusChip(
                  status: StatusChip.fromString(order.status),
                ),
                const Spacer(),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.navyMuted,
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Date · items count · total
            Row(
              children: [
                Text(
                  _fmtDate(order.createdAt),
                  style: const TextStyle(
                    color: AppColors.navyMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  '·',
                  style: TextStyle(color: AppColors.navyMuted, fontSize: 12),
                ),
                const SizedBox(width: 6),
                Text(
                  '${order.items.length} ${_itemWord(order.items.length)}',
                  style: const TextStyle(
                    color: AppColors.navyMuted,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  formatMoney(order.totalAmount),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),

            // Shipped row
            if (order.status == 'shipped') ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.local_shipping_outlined,
                      size: 14, color: AppColors.purple),
                  SizedBox(width: 6),
                  Text(
                    'Заказ в пути',
                    style: TextStyle(
                      color: AppColors.purple,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],

            // Pending payment warning
            if (isPending) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded,
                      size: 14, color: AppColors.error),
                  const SizedBox(width: 6),
                  Text(
                    'Ожидает оплаты',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],

            // Reorder button for completed
            if (onReorder != null) ...[
              const SizedBox(height: 8),
              const Divider(height: 1, color: AppColors.border),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onReorder,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.purple,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 0, vertical: 8),
                    textStyle: const TextStyle(
                      fontFamily: 'NunitoSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.replay_rounded, size: 15),
                      SizedBox(width: 4),
                      Text('Повторить'),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Card skeleton ─────────────────────────────────────────────────────────────

class _OrderCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
              Skeleton.rect(width: 90, height: 16),
              const SizedBox(width: 10),
              Skeleton.rect(width: 70, height: 22, radius: 11),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Skeleton.rect(width: 110, height: 13),
              const Spacer(),
              Skeleton.rect(width: 70, height: 16),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Formatters ────────────────────────────────────────────────────────────────

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
