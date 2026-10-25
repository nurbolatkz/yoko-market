import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/address_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/orders_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/error_state.dart';
import 'addresses_screen.dart';
import 'auth/account_recovery_screen.dart';
import 'auth/phone_screen.dart';
import 'delivery_info_screen.dart';
import 'invite_screen.dart';
import 'orders_screen.dart';
import 'reorder_screen.dart';
import 'settings_screen.dart';
import 'personal_data_screen.dart';
import 'support_screen.dart';
import 'yocoin_history_screen.dart';

// Profile screen uses a light-lavender tint (#F8F7FC) rather than the app's
// default warm-white (#FAF9F6) to match the design reference.
const _kProfileBg = Color(0xFFF8F7FC);

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.state == AuthState.unknown) {
      return const Scaffold(backgroundColor: _kProfileBg);
    }

    if (auth.state == AuthState.sessionExpired) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Профиль',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 64, color: AppColors.navyMuted),
                const SizedBox(height: 16),
                Text(
                  'Сессия истекла',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Войдите снова, чтобы увидеть заказы и бонусы.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.navyMuted, height: 1.4),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PhoneScreen()),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Войти', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (auth.state == AuthState.sessionError) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Профиль',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: Center(
          child: ErrorState(
            message: 'Проверьте интернет и попробуйте ещё раз.',
            onRetry: () => context.read<AuthProvider>().retryInit(),
          ),
        ),
      );
    }

    if (!auth.isAuthenticated) {
      return _GuestView(
        onLogin: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PhoneScreen()),
        ),
      );
    }

    return _AuthenticatedView(auth: auth);
  }
}

// ── Guest view ────────────────────────────────────────────────────────────────

class _GuestView extends StatelessWidget {
  const _GuestView({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person_outline_rounded,
                size: 72,
                color: AppColors.purple,
              ),
              const SizedBox(height: 16),
              Text(
                'Войдите в аккаунт',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Чтобы отслеживать заказы и накапливать бонусы',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onLogin,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Войти', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Authenticated view ────────────────────────────────────────────────────────

class _AuthenticatedView extends StatefulWidget {
  const _AuthenticatedView({required this.auth});

  final AuthProvider auth;

  @override
  State<_AuthenticatedView> createState() => _AuthenticatedViewState();
}

class _AuthenticatedViewState extends State<_AuthenticatedView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<OrdersProvider>().fetchOrders(context.read<AuthProvider>());
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.user!;
    final op = context.watch<OrdersProvider>();
    final lastDelivered = (!op.loading && op.error == null)
        ? op.orders.where((o) => o.status == 'delivered').firstOrNull
        : null;

    return Scaffold(
      backgroundColor: _kProfileBg,
      appBar: AppBar(
        backgroundColor: _kProfileBg,
        title: const Text('Профиль'),
        actions: [
          TextButton.icon(
            onPressed: () => _confirmLogout(context, widget.auth),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Выйти'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // 1. Header: greeting + phone
          _ProfileHeader(phone: user.phone, fullName: user.fullName),
          const SizedBox(height: 16),

          // 2. Loyalty card — taps through to YoCoin history
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const YoCoinHistoryScreen(),
              ),
            ),
            child: _LoyaltyCard(
              balance: user.bonusBalance,
              tierLabel: user.loyaltyTierLabel,
            ),
          ),

          // 3. Reorder button — only visible when a delivered order exists
          if (lastDelivered != null) ...[
            const SizedBox(height: 12),
            _ReorderButton(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReorderScreen(order: lastDelivered),
                ),
              ),
            ),
          ],

          // 4. Menu
          const SizedBox(height: 16),
          _buildMenu(context),
        ],
      ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    return Column(
      children: [
        // Мои заказы → existing OrdersScreen
        _MenuItem(
          title: 'Мои заказы',
          subtitle: 'Статусы и история',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const OrdersScreen()),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AccountRecoveryScreen()),
            ),
            icon: const Icon(Icons.history_rounded,
                size: 18, color: AppColors.navyMuted),
            label: const Text('Не видите старые заказы?',
                style:
                    TextStyle(color: AppColors.navyMuted, fontSize: 13)),
          ),
        ),
        const SizedBox(height: 8),
        _MenuItem(
          title: 'История монет',
          subtitle: 'Начисления и списания',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const YoCoinHistoryScreen()),
          ),
        ),
        const SizedBox(height: 8),
        _MenuItem(
          title: 'Пригласить друга',
          subtitle: 'Код и условия приглашения',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InviteScreen()),
          ),
        ),
        const SizedBox(height: 8),
        const _MenuItem(
          title: 'Игры',
          subtitle: 'Развлечения и награды',
        ),
        const SizedBox(height: 8),
        _MenuItem(
          title: 'Мои адреса',
          subtitle: 'Адреса доставки',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddressesScreen()),
          ),
        ),
        const SizedBox(height: 8),
        _MenuItem(
          title: 'Доставка и оплата',
          subtitle: 'Условия, города, способы оплаты',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DeliveryInfoScreen()),
          ),
        ),
        const SizedBox(height: 8),
        _MenuItem(
          title: 'Личные данные',
          subtitle: 'Имя и контактная информация',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PersonalDataScreen()),
          ),
        ),
        const SizedBox(height: 8),
        _MenuItem(
          title: 'Поддержка / FAQ',
          subtitle: 'Вопросы, доставка, возврат',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SupportScreen()),
          ),
        ),
        const SizedBox(height: 8),
        _MenuItem(
          title: 'Настройки',
          subtitle: 'Версия, политика, выход',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context, AuthProvider auth) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              ctx.read<OrdersProvider>().clearOrders();
              ctx.read<AddressProvider>().clear();
              auth.logout();
              Navigator.pop(ctx);
            },
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }
}

// ── Profile header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.phone, required this.fullName});

  final String phone;
  final String? fullName;

  @override
  Widget build(BuildContext context) {
    final first = _firstName(fullName);
    final greeting = first != null ? 'Сәлем, $first' : 'Сәлем!';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatPhone(phone),
          style: const TextStyle(
            color: AppColors.navyMuted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Loyalty card ──────────────────────────────────────────────────────────────

class _LoyaltyCard extends StatelessWidget {
  const _LoyaltyCard({required this.balance, required this.tierLabel});

  final int balance;
  final String? tierLabel;

  @override
  Widget build(BuildContext context) {
    final label = (tierLabel ?? 'МОИ YOCOIN').toUpperCase();
    return Semantics(
      label: 'Бонусный баланс: $balance YoCoin',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.purple,
          borderRadius: AppRadii.cardBorder,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.70),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _fmtBalance(balance),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Бонусы для следующих покупок',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 14),
            const Text(
              'До 10% кэшбэка · До 100% заказа бонусами',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Бесплатная доставка от 10 000 ₸',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reorder button ────────────────────────────────────────────────────────────

class _ReorderButton extends StatelessWidget {
  const _ReorderButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.replay_rounded, size: 18),
        label: const Text('Повторить заказ'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
        ),
      ),
    );
  }
}

// ── Menu item ─────────────────────────────────────────────────────────────────

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  bool get _available => onTap != null;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: _available,
      enabled: _available,
      label: _available ? null : '$title — скоро',
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadii.cardBorder,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.cardBorder,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: _available ? AppColors.navy : AppColors.navyMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.navyMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (_available)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.navyMuted,
                    size: 20,
                  )
                else
                  const _SoonBadge(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SoonBadge extends StatelessWidget {
  const _SoonBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.purpleSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Скоро',
        style: TextStyle(
          color: AppColors.purple,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

// Returns the first name from a full name string, or null if unavailable.
String? _firstName(String? fullName) {
  if (fullName == null || fullName.trim().isEmpty) return null;
  return fullName.trim().split(RegExp(r'\s+')).first;
}

// Formats an E.164 KZ phone number (+7XXXXXXXXXX) as +7 XXX XXX XX XX.
String _formatPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11 && digits.startsWith('7')) {
    final n = digits.substring(1);
    return '+7 ${n.substring(0, 3)} ${n.substring(3, 6)} '
        '${n.substring(6, 8)} ${n.substring(8, 10)}';
  }
  return phone;
}

// Formats an integer balance with thousands separators (space-separated).
String _fmtBalance(int amount) {
  if (amount == 0) return '0';
  return amount.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]} ',
  );
}
