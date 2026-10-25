import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/address_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/market_provider.dart';
import '../providers/orders_provider.dart';
import '../providers/wishlist_provider.dart';
import '../services/legal_settings_api.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/app_button.dart';
import 'auth/otp_screen.dart';

// Orders that block account deletion on the client side.
// pending_payment is included because cancelling an in-flight payment without
// user awareness is disruptive; confirmed/payment_received/shipped cannot be
// cancelled by the backend at all.
const _kBlockingStatuses = {
  'pending_payment',
  'confirmed',
  'payment_received',
  'shipped',
};

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  bool _showDone = false;
  bool _requesting = false;
  String? _error;
  LegalUrls? _legal;

  @override
  void initState() {
    super.initState();
    _loadLegal();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureOrdersLoaded());
  }

  void _ensureOrdersLoaded() {
    if (!mounted) return;
    final prov = context.read<OrdersProvider>();
    if (prov.orders.isEmpty && !prov.loading && prov.error == null) {
      prov.fetchOrders(context.read<AuthProvider>());
    }
  }

  Future<void> _loadLegal() async {
    try {
      final urls = await LegalSettingsApi().getLegalUrls();
      if (!mounted) return;
      setState(() => _legal = urls);
    } catch (_) {}
  }

  Future<void> _openPrivacy() async {
    final url = _legal?.privacyUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _startDeletion() async {
    final auth = context.read<AuthProvider>();
    final phone = auth.user?.phone;
    if (phone == null || phone.isEmpty) return;

    setState(() {
      _requesting = true;
      _error = null;
    });

    int ttl;
    try {
      ttl = await auth.requestOtp(phone);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = _mapOtpRequestError(e));
      return;
    } finally {
      if (mounted) setState(() => _requesting = false);
    }

    if (!mounted) return;
    final confirmed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OtpScreen(
          phone: phone,
          ttl: ttl,
          returnResultOnSuccess: true,
        ),
      ),
    );
    if (!mounted || confirmed != true) return;

    await _doDelete();
  }

  Future<void> _doDelete() async {
    setState(() {
      _requesting = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().deleteAccount();
      if (!mounted) return;
      context.read<WishlistProvider>().clearForUser();
      context.read<OrdersProvider>().clearOrders();
      context.read<AddressProvider>().clear();
      context.read<MarketProvider>().clearCart();
      if (mounted) setState(() => _showDone = true);
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = (e.response?.data is Map)
          ? (e.response!.data as Map)['detail'] as String?
          : null;
      final msg = detail == 'active_orders'
          ? 'Есть активные заказы. Дождитесь их завершения.'
          : 'Ошибка соединения. Попробуйте позже.';
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  static String _mapOtpRequestError(DioException e) {
    final detail = (e.response?.data is Map)
        ? (e.response!.data as Map)['detail'] as String?
        : null;
    return switch (detail) {
      'too_many_requests' => 'Слишком много запросов. Подождите минуту.',
      'sms_not_configured' => 'SMS-сервис временно недоступен.',
      _ => 'Ошибка соединения. Проверьте сеть.',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_showDone) return _buildDone(context);
    return _buildInfo(context);
  }

  // ── Done screen ─────────────────────────────────────────────────────────────

  Widget _buildDone(BuildContext context) {
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x3l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                size: 72,
                color: AppColors.success,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Аккаунт удалён',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Ваши данные будут удалены в течение 30 дней.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.navyMuted, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: AppSpacing.x3l),
              AppButton(
                label: 'На главную',
                onPressed: () => Navigator.of(context)
                    .popUntil((route) => route.isFirst),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Info screen ─────────────────────────────────────────────────────────────

  Widget _buildInfo(BuildContext context) {
    final orders = context.watch<OrdersProvider>();
    final auth = context.watch<AuthProvider>();
    final bonusBalance = auth.user?.bonusBalance ?? 0;

    final hasBlockingOrders =
        orders.orders.any((o) => _kBlockingStatuses.contains(o.status));
    final canProceed = !orders.loading && !hasBlockingOrders && !_requesting;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Удаление аккаунта',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.x2l,
          AppSpacing.xl,
          AppSpacing.x3l,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            const Icon(
              Icons.no_accounts_outlined,
              size: 56,
              color: AppColors.navyMuted,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Вы уверены?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'После подтверждения аккаунт будет удалён. Это действие необратимо.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.navyMuted, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.x2l),

            // Warnings
            if (bonusBalance > 0) ...[
              _WarningCard(
                icon: Icons.monetization_on_outlined,
                color: const Color(0xFFB45309),
                message:
                    'Вы потеряете ${_fmt(bonusBalance)} ₸ YoCoin-бонусов.',
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (orders.loading)
              _WarningCard(
                icon: Icons.hourglass_empty_rounded,
                color: AppColors.navyMuted,
                message: 'Проверяем активные заказы…',
                showSpinner: true,
              )
            else if (hasBlockingOrders)
              _WarningCard(
                icon: Icons.local_shipping_outlined,
                color: AppColors.error,
                message:
                    'Есть активные заказы. Дождитесь их доставки или отмены.',
              ),
            const SizedBox(height: AppSpacing.xl),

            // Privacy policy link
            if (_legal?.privacyUrl.isNotEmpty == true)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _openPrivacy,
                  icon: const Icon(Icons.open_in_new_rounded, size: 15),
                  label: const Text('Политика конфиденциальности'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.navyMuted,
                    padding: EdgeInsets.zero,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.x3l),

            // Error
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.25)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                      color: AppColors.error, fontSize: 13, height: 1.4),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // Primary: keep account
            AppButton(
              label: 'Оставить аккаунт',
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Secondary: destructive confirmation
            AppButton(
              label: 'Продолжить удаление',
              variant: canProceed
                  ? AppButtonVariant.secondary
                  : AppButtonVariant.disabled,
              loading: _requesting,
              onPressed: canProceed ? _startDeletion : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Warning card ──────────────────────────────────────────────────────────────

class _WarningCard extends StatelessWidget {
  const _WarningCard({
    required this.icon,
    required this.color,
    required this.message,
    this.showSpinner = false,
  });

  final IconData icon;
  final Color color;
  final String message;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          showSpinner
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: color),
                )
              : Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmt(int amount) => amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );
