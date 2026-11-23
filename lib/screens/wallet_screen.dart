import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/wallet.dart';
import '../providers/auth_provider.dart';
import '../services/wallet_api.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/cashback_progress_card.dart';
import '../widgets/gift_card_activation_sheet.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/ui/empty_state.dart';
import '../widgets/ui/error_state.dart';
import '../widgets/ui/hero_balance_card.dart';
import '../widgets/ui/skeleton.dart';

/// «Мой кошелёк»: gift balance, YoCoin with this month's cashback progress,
/// gift-card activation and the combined history.
///
/// Data from [WalletApi] — mock by default (`MOCK_WALLET=true`) until the
/// backend ships `/wallet` and `/gift-cards/*`.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, this.api});

  /// Injected in tests; defaults to [WalletApi()].
  final WalletApi? api;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late final WalletApi _api = widget.api ?? WalletApi();

  Wallet? _wallet;
  final List<WalletTx> _history = [];
  int? _nextCursor;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<String?> _token() => context.read<AuthProvider>().getAccessToken();

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final token = await _token();
    if (!mounted) return;
    if (token == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        _api.getWallet(token),
        _api.getHistory(token),
      ]);
      if (!mounted) return;
      final page = results[1] as WalletHistoryPage;
      setState(() {
        _wallet = results[0] as Wallet;
        _history
          ..clear()
          ..addAll(page.items);
        _nextCursor = page.nextCursor;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить кошелёк. Проверьте подключение.';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    final token = await _token();
    if (!mounted || token == null) return;
    try {
      final page = await _api.getHistory(token, cursor: cursor);
      if (!mounted) return;
      setState(() {
        _history.addAll(page.items);
        _nextCursor = page.nextCursor;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить историю')),
      );
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _activate() async {
    final token = await _token();
    if (!mounted || token == null) return;
    final result = await showGiftCardActivationSheet(
      context,
      api: _api,
      token: token,
    );
    if (result != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Мой кошелёк',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(top: false, child: _body(auth)),
    );
  }

  Widget _body(AuthProvider auth) {
    if (!auth.isAuthenticated) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.x3l),
          child: Text(
            'Войдите в аккаунт, чтобы видеть кошелёк',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.navyMuted, fontSize: 15),
          ),
        ),
      );
    }
    if (_loading) return const _WalletSkeleton();
    if (_error != null) {
      return Center(child: ErrorState(message: _error, onRetry: _load));
    }
    final wallet = _wallet!;
    final cashback = wallet.cashback;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.x3l,
        ),
        children: [
          if (AppConfig.mockWallet) ...[
            const _DemoNotice(),
            const SizedBox(height: AppSpacing.md),
          ],
          HeroBalanceCard(
            topLabel: 'Подарочный баланс',
            value: formatMoney(wallet.giftBalance),
            subtitle: wallet.giftBalance > 0 && wallet.giftExpiresAt != null
                ? 'Действует до ${formatDate(wallet.giftExpiresAt!)}'
                : 'Активируйте подарочную карту — баланс можно '
                    'потратить на любые товары',
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Активировать карту',
            icon: const Icon(Icons.card_giftcard_rounded, size: 20),
            onPressed: _activate,
          ),
          const SizedBox(height: AppSpacing.lg),
          _YoCoinBalance(balance: wallet.yocoinBalance),
          if (cashback != null) ...[
            const SizedBox(height: AppSpacing.md),
            CashbackProgressCard(cashback: cashback),
          ],
          const SizedBox(height: AppSpacing.x2l),
          const Text(
            'История',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_history.isEmpty)
            const EmptyState(
              icon: Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: AppColors.navyMuted,
              ),
              headline: 'Пока пусто',
              body: 'Здесь появятся начисления YoCoin, подарки и оплаты.',
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < _history.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, color: AppColors.border),
                    _TxRow(tx: _history[i]),
                  ],
                ],
              ),
            ),
          if (_nextCursor != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: _loadingMore
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.purple,
                        ),
                      ),
                    )
                  : TextButton(
                      onPressed: _loadMore,
                      child: const Text('Показать ещё'),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.warnSoft,
        borderRadius: AppRadii.buttonBorder,
      ),
      child: const Row(
        children: [
          Icon(Icons.science_outlined, size: 18, color: AppColors.warn),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Демо-данные: кошелёк ещё не подключён к серверу',
              style: TextStyle(fontSize: 13, color: AppColors.warn),
            ),
          ),
        ],
      ),
    );
  }
}

class _YoCoinBalance extends StatelessWidget {
  const _YoCoinBalance({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.yellow,
              shape: BoxShape.circle,
            ),
            child: const Text(
              'Y',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.purple,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YoCoin',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  '1 YoCoin = 1 ₸ при оплате заказа',
                  style: TextStyle(fontSize: 12, color: AppColors.navyMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            formatNumber(balance),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({required this.tx});

  final WalletTx tx;

  @override
  Widget build(BuildContext context) {
    final isGift = tx.kind == WalletTxKind.gift;
    final sign = tx.isCredit ? '+' : '−';
    final amount = isGift
        ? '$sign${formatMoney(tx.amount.abs())}'
        : '$sign${formatNumber(tx.amount.abs())} YoCoin';
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(
            isGift ? Icons.card_giftcard_rounded : Icons.toll_rounded,
            size: 22,
            color: isGift ? AppColors.purple : AppColors.warn,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  formatDate(tx.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.navyMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              amount,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: tx.isCredit ? AppColors.success : AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletSkeleton extends StatelessWidget {
  const _WalletSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: const [
        Skeleton(height: 132, radius: AppRadii.card),
        SizedBox(height: AppSpacing.md),
        Skeleton(height: 52, radius: AppRadii.button),
        SizedBox(height: AppSpacing.lg),
        Skeleton(height: 76, radius: AppRadii.card),
        SizedBox(height: AppSpacing.md),
        Skeleton(height: 150, radius: AppRadii.card),
        SizedBox(height: AppSpacing.x2l),
        Skeleton(height: 220, radius: AppRadii.card),
      ],
    );
  }
}
