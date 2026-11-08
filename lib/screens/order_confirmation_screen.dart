import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/checkout_estimate.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ui/summary_rows.dart';
import 'order_detail_screen.dart';
import 'orders_screen.dart';

class OrderConfirmationScreen extends StatefulWidget {
  const OrderConfirmationScreen({
    super.key,
    required this.result,
    this.expectedTotal,
    this.address,
    this.promoDiscount = 0,
    this.bonusUsed = 0,
  });

  final PlaceOrderResult result;
  final int? expectedTotal;
  final String? address;
  final int promoDiscount;
  final int bonusUsed;

  bool get _priceAdjusted =>
      expectedTotal != null && expectedTotal != result.total;

  @override
  State<OrderConfirmationScreen> createState() =>
      _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    final reduceMotion =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.reduceMotion;

    if (reduceMotion) {
      _ctrl = AnimationController(vsync: this, duration: Duration.zero);
      _scale = const AlwaysStoppedAnimation(1.0);
      _fade = const AlwaysStoppedAnimation(1.0);
    } else {
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 480),
      );
      _scale = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
      );
      _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.forward());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _openTelegram() async {
    final bot = widget.result.botUsername;
    if (bot == null) return;
    final text = Uri.encodeComponent('Оплата заказа #${widget.result.orderNumber}');
    final uri = Uri.parse('https://t.me/$bot?text=$text');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _viewOrder() {
    final orderId = widget.result.id;
    if (orderId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(orderId: orderId),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const OrdersScreen()),
      );
    }
  }

  void _continueShopping() =>
      Navigator.of(context).popUntil((r) => r.isFirst);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTelegram = widget.result.botUsername != null;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Animated checkmark ──
              Center(
                child: ScaleTransition(
                  scale: _scale,
                  child: FadeTransition(
                    opacity: _fade,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success.withValues(alpha: 0.1),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 56,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Heading ──
              Text(
                'Спасибо за покупку!',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Заказ № ${widget.result.orderNumber} создан',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.navyMuted,
                ),
              ),
              const SizedBox(height: 24),

              // ── Payment card ──
              Container(
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
                            'Оплатите в течение 30 минут',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Если оплата не поступит, заказ отменится автоматически.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.navyMuted,
                        height: 1.4,
                      ),
                    ),
                    if (hasTelegram) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const Key('confirm-pay-telegram'),
                          onPressed: _openTelegram,
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
                      const SizedBox(height: 10),
                      Text(
                        'Откроется Telegram-бот магазина. Отправьте скриншот оплаты — менеджер подтвердит заказ.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.navyMuted,
                          height: 1.4,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      Text(
                        'Свяжитесь с менеджером, чтобы подтвердить оплату.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.navyMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Delivery address card ──
              if (widget.address != null && widget.address!.isNotEmpty) ...[
                _InfoCard(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 18, color: AppColors.navyMuted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Адрес доставки',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: AppColors.navyMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.address!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // ── Order total card ──
              _InfoCard(
                children: [
                  if (widget._priceAdjusted) ...[
                    Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 14, color: AppColors.navyMuted),
                        const SizedBox(width: 6),
                        Text(
                          'Сумма уточнена сервером',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  SummaryRows(
                    rows: [
                      if (widget.promoDiscount > 0)
                        SummaryRow(
                          label: 'Промокод',
                          value: '−${formatMoney(widget.promoDiscount)}',
                          valueColor: AppColors.success,
                        ),
                      if (widget.bonusUsed > 0)
                        SummaryRow(
                          label: 'Бонусы',
                          value: '−${formatMoney(widget.bonusUsed)}',
                          valueColor: AppColors.purple,
                        ),
                      SummaryRow(
                        label: 'К оплате',
                        value: formatMoney(widget.result.total),
                        isTotal: true,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Buttons ──
              OutlinedButton(
                key: const Key('confirm-view-orders'),
                onPressed: _viewOrder,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.button),
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
                onPressed: _continueShopping,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.button),
                  ),
                ),
                child: const Text(
                  'Продолжить покупки',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
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
