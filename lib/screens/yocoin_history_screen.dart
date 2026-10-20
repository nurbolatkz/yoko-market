import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'auth/phone_screen.dart';

class YoCoinHistoryScreen extends StatefulWidget {
  const YoCoinHistoryScreen({super.key});

  @override
  State<YoCoinHistoryScreen> createState() => _YoCoinHistoryScreenState();
}

class _YoCoinHistoryScreenState extends State<YoCoinHistoryScreen> {
  static const _pageSize = 20;

  final _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  final _scrollController = ScrollController();

  int _balance = 0;
  final List<_BonusTx> _items = [];
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || _loading) return;
    if (_items.length >= _total) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _items.clear();
        _total = 0;
      });
    }

    final token = await context.read<AuthProvider>().getAccessToken();
    if (!mounted) return;
    if (token == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final resp = await _dio.get<dynamic>(
        '/mobile/bonus-history',
        queryParameters: {'offset': 0, 'limit': _pageSize},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = resp.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _balance = (data['balance'] as num).toInt();
        _total = (data['total'] as num).toInt();
        _items
          ..clear()
          ..addAll(_parseItems(data['items']));
        _loading = false;
        _error = null;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = (e.response?.statusCode ?? 0) == 401
            ? 'Сессия истекла. Войдите снова.'
            : 'Не удалось загрузить историю.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить историю.';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _items.length >= _total) return;
    setState(() => _loadingMore = true);

    final token = await context.read<AuthProvider>().getAccessToken();
    if (!mounted) return;
    if (token == null) {
      setState(() => _loadingMore = false);
      return;
    }

    try {
      final resp = await _dio.get<dynamic>(
        '/mobile/bonus-history',
        queryParameters: {'offset': _items.length, 'limit': _pageSize},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = resp.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _balance = (data['balance'] as num).toInt();
        _total = (data['total'] as num).toInt();
        _items.addAll(_parseItems(data['items']));
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  List<_BonusTx> _parseItems(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map(_BonusTx.fromJson).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isAuthenticated) {
      return _GuestPrompt(
        onLogin: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PhoneScreen()),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'История YoCoin',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Column(
        children: [
          _BalanceHeader(balance: _balance),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }

    if (_error != null) {
      return Column(
        children: [
          _BalanceHeader(balance: _balance),
          Expanded(
            child: _ErrorView(message: _error!, onRetry: () => _load(reset: true)),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return Column(
        children: [
          _BalanceHeader(balance: _balance),
          const Expanded(child: _EmptyState()),
        ],
      );
    }

    return Column(
      children: [
        _BalanceHeader(balance: _balance),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(reset: true),
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: _items.length + (_loadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _items.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }

                final tx = _items[index];
                final prevTx = index > 0 ? _items[index - 1] : null;
                final showDateSeparator = prevTx == null ||
                    !_sameDay(prevTx.createdAt, tx.createdAt);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showDateSeparator) _DateSeparator(date: tx.createdAt),
                    _TxCard(tx: tx),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _fmtBalance(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );

String _fmtDate(DateTime dt) {
  const months = [
    'янв', 'фев', 'мар', 'апр', 'май', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

String _fmtTime(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

// ── Balance header ────────────────────────────────────────────────────────────

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: const BoxDecoration(
        color: AppColors.purple,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ТЕКУЩИЙ БАЛАНС',
            style: TextStyle(
              color: Colors.white.withAlpha(180),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _fmtBalance(balance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'YoCoin',
                style: TextStyle(
                  color: Colors.white.withAlpha(200),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Date separator ────────────────────────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(
        _fmtDate(date),
        style: const TextStyle(
          color: AppColors.navyMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ── Transaction card ──────────────────────────────────────────────────────────

class _TxCard extends StatelessWidget {
  const _TxCard({required this.tx});

  final _BonusTx tx;

  @override
  Widget build(BuildContext context) {
    final isAccrual = tx.type == 'accrual';
    final amountColor =
        isAccrual ? const Color(0xFF23804A) : AppColors.navyMuted;
    final amountPrefix = isAccrual ? '+' : '−';
    final icon =
        isAccrual ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded;
    final iconColor = isAccrual ? const Color(0xFF23804A) : AppColors.navyMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardBorder,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isAccrual
                  ? const Color(0xFFEAF7EF)
                  : AppColors.purpleSoft.withAlpha(100),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAccrual ? 'Начисление' : 'Списание',
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _fmtTime(tx.createdAt),
                      style: const TextStyle(
                        color: AppColors.navyMuted,
                        fontSize: 12,
                      ),
                    ),
                    if (tx.orderNumber != null) ...[
                      const Text(
                        '  ·  ',
                        style: TextStyle(
                          color: AppColors.navyMuted,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '№${tx.orderNumber}',
                        style: const TextStyle(
                          color: AppColors.navyMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$amountPrefix${_fmtBalance(tx.amount)}',
                style: TextStyle(
                  color: amountColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'баланс ${_fmtBalance(tx.balanceAfter)}',
                style: const TextStyle(
                  color: AppColors.navyMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.monetization_on_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'Операций пока нет',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'YoCoin начисляются после подтверждения заказа',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.navyMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Повторить'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Guest prompt ──────────────────────────────────────────────────────────────

class _GuestPrompt extends StatelessWidget {
  const _GuestPrompt({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'История YoCoin',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.monetization_on_outlined,
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
                'Чтобы видеть начисления и списания YoCoin',
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

// ── Data model ────────────────────────────────────────────────────────────────

class _BonusTx {
  const _BonusTx({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.createdAt,
    this.orderNumber,
  });

  final String id;
  final String type;
  final int amount;
  final int balanceAfter;
  final DateTime createdAt;
  final String? orderNumber;

  factory _BonusTx.fromJson(Map<String, dynamic> j) => _BonusTx(
        id: j['id'] as String,
        type: j['type'] as String,
        amount: (j['amount'] as num).toInt(),
        balanceAfter: (j['balance_after'] as num).toInt(),
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
        orderNumber: j['order_number'] as String?,
      );
}
