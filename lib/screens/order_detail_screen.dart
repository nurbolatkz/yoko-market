import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/order.dart';
import '../providers/auth_provider.dart';
import '../services/orders_api.dart';
import '../theme/app_theme.dart';
import '../utils/dio_error.dart';
import '../utils/format.dart';
import '../utils/order_status.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/error_state.dart';
import '../widgets/ui/order_progress.dart';
import '../widgets/ui/skeleton.dart';
import '../widgets/ui/summary_rows.dart';
import 'reorder_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  /// Pass exactly one of [order] (from orders list) or [orderId] (from
  /// confirmation screen, requires backend checkout_service v3+).
  const OrderDetailScreen({super.key, this.order, this.orderId})
      : assert(
          order != null || orderId != null,
          'Provide order or orderId',
        );

  final OrderSummary? order;
  final String? orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen>
    with WidgetsBindingObserver {
  final _api = OrdersApi();

  OrderSummary? _order;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.order != null) {
      _order = widget.order;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final o = _order;
      if (o != null && OrderStatus.isActive(o.status)) _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      String? token = await auth.getAccessToken();
      token ??= await auth.ensureFreshToken();
      if (token == null) {
        if (mounted) setState(() { _error = 'auth'; _loading = false; });
        return;
      }

      final id = _order?.id ?? widget.orderId!;
      final order = await _api.getOrder(id: id, token: token);
      if (mounted) setState(() { _order = order; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() { _error = networkErrorMessage(e); _loading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;

    if (_loading && order == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.orderId != null
                ? 'Заказ'
                : 'Заказ № ${widget.order?.orderNumber ?? '…'}',
          ),
        ),
        body: const _DetailSkeleton(),
      );
    }

    if (_error != null && order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Заказ')),
        body: Center(
          child: ErrorState(
            message: _error == 'auth'
                ? 'Сессия истекла. Войдите снова.'
                : _error,
            onRetry: _load,
          ),
        ),
      );
    }

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Заказ')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '№ ${order.orderNumber}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            Text(
              _fmtDateTime(order.createdAt),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.navyMuted,
              ),
            ),
          ],
        ),
        toolbarHeight: 60,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // ── Status progress bar ──
            OrderProgress(status: order.status),
            const SizedBox(height: 16),

            // ── Pending payment block ──
            if (order.status == 'pending_payment') ...[
              _PendingPaymentCard(orderNumber: order.orderNumber),
              const SizedBox(height: 16),
            ],

            // ── Items ──
            _SectionLabel(title: 'Товары (${order.items.length})'),
            const SizedBox(height: 8),
            _InfoCard(
              children: [
                for (int i = 0; i < order.items.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, color: AppColors.border),
                  _ItemRow(item: order.items[i]),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // ── Delivery address ──
            if (order.address.isNotEmpty) ...[
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
                            color: AppColors.navy,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // ── Payment breakdown ──
            _SectionLabel(title: 'Расчёт'),
            const SizedBox(height: 8),
            _InfoCard(
              children: [
                SummaryRows(
                  rows: [
                    SummaryRow(
                      label: 'Товары',
                      value: formatMoney(
                          order.items.fold(0, (s, i) => s + i.lineTotal)),
                    ),
                    if (order.promoDiscount > 0)
                      SummaryRow(
                        label: order.promoCodeUsed != null
                            ? 'Промокод (${order.promoCodeUsed})'
                            : 'Промокод',
                        value: '−${formatMoney(order.promoDiscount)}',
                        valueColor: AppColors.success,
                      ),
                    if (order.bonusUsed > 0)
                      SummaryRow(
                        label: 'Бонусы',
                        value: '−${formatMoney(order.bonusUsed)}',
                        valueColor: AppColors.purple,
                      ),
                    SummaryRow(
                      label: 'Итого',
                      value: formatMoney(order.totalAmount),
                      isTotal: true,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Bottom buttons ──
            if (OrderStatus.isCompleted(order.status)) ...[
              AppButton(
                label: 'Повторить заказ',
                icon: const Icon(Icons.replay_rounded, size: 18),
                fullWidth: true,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ReorderScreen(order: order)),
                ),
              ),
              const SizedBox(height: 10),
            ],
            AppButton(
              label: 'Связаться с поддержкой',
              variant: AppButtonVariant.secondary,
              fullWidth: true,
              onPressed: () => _openSupport(order.orderNumber),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSupport(String orderNumber) async {
    final uri = Uri.parse(
        'https://t.me/yokomarket_support?text=${Uri.encodeComponent('Помощь с заказом #$orderNumber')}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ── Pending payment card ──────────────────────────────────────────────────────

class _PendingPaymentCard extends StatelessWidget {
  const _PendingPaymentCard({required this.orderNumber});

  final String orderNumber;

  Future<void> _openTelegram(BuildContext context) async {
    final text = Uri.encodeComponent('Оплата заказа #$orderNumber');
    final uri = Uri.parse('https://t.me/yokomarket?text=$text');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.yellowSoft,
        borderRadius: AppRadii.cardBorder,
        border: Border.all(color: AppColors.yellow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time_rounded,
                  size: 18, color: AppColors.navy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ожидаем оплату',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Заказ автоматически отменится, если оплата не поступит в течение 30 минут.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.navyMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openTelegram(context),
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Оплатить через Telegram'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.button),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Skeleton.rect(height: 80, radius: AppRadii.card),
        const SizedBox(height: 16),
        Skeleton.rect(height: 24, width: 120),
        const SizedBox(height: 8),
        Skeleton.rect(height: 100, radius: AppRadii.card),
        const SizedBox(height: 16),
        Skeleton.rect(height: 24, width: 100),
        const SizedBox(height: 8),
        Skeleton.rect(height: 80, radius: AppRadii.card),
      ],
    );
  }
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
      padding: const EdgeInsets.all(16),
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
                '${item.qty} × ${formatMoney(item.unitPrice)}',
                style: const TextStyle(
                    color: AppColors.navyMuted, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                formatMoney(item.lineTotal),
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

// ── Formatters ────────────────────────────────────────────────────────────────

String _fmtDateTime(DateTime dt) {
  final local = dt.toLocal();
  final months = [
    'янв', 'фев', 'мар', 'апр', 'май', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
  ];
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${months[local.month - 1]} ${local.year}, $hh:$mm';
}
