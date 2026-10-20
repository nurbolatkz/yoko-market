import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

// ── Entry point ────────────────────────────────────────────────────────────────

class YoCoinScreen extends StatefulWidget {
  const YoCoinScreen({super.key});

  @override
  State<YoCoinScreen> createState() => _YoCoinScreenState();
}

class _YoCoinScreenState extends State<YoCoinScreen> {
  final _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  _LoyaltyRules? _rules;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await _dio.get<dynamic>('/loyalty/rules');
      final data = resp.data as Map<String, dynamic>;
      setState(() {
        _rules = _LoyaltyRules.fromJson(data);
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.message ?? 'Ошибка сети';
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Не удалось загрузить правила';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroHeader(
                balance: user?.bonusBalance ?? 0,
                tierLabel: user?.loyaltyTierLabel,
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: _ErrorView(message: _error!, onRetry: _load),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              sliver: SliverList.list(
                children: [
                  _RulesSection(rules: _rules!),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Hero header ────────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.balance, this.tierLabel});

  final int balance;
  final String? tierLabel;

  @override
  Widget build(BuildContext context) {
    final label = (tierLabel ?? 'Новичок').toUpperCase();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A2FA0), AppColors.purple],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'МОИ YoCoin',
            style: TextStyle(
              color: Colors.white.withAlpha(180),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _fmtBalance(balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Rules section ─────────────────────────────────────────────────────────────

class _RulesSection extends StatelessWidget {
  const _RulesSection({required this.rules});

  final _LoyaltyRules rules;

  @override
  Widget build(BuildContext context) {
    final accrual = rules.accrual;
    final redemption = rules.redemption;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RuleCard(
          icon: Icons.trending_up_rounded,
          iconColor: const Color(0xFF23804A),
          title: 'Как начисляются YoCoin',
          children: [
            _RuleRow(
              text:
                  'За каждый подтверждённый заказ начисляется ${accrual.defaultPct}% от суммы заказа.',
            ),
            _RuleRow(
              text:
                  'Начисление применяется при заказе от ${_fmtAmount(accrual.minOrderAmount)} ₸.',
            ),
            _RuleRow(
              text:
                  'Чем выше ваш уровень — тем больше процент начислений.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _RuleCard(
          icon: Icons.shopping_cart_outlined,
          iconColor: AppColors.purple,
          title: 'Когда можно использовать',
          children: [
            _RuleRow(
              text:
                  'YoCoin списываются при оформлении заказа в разделе «Корзина → Оформить».',
            ),
            _RuleRow(
              text:
                  'Максимально можно списать ${redemption.maxPctOfOrder}% от суммы заказа.',
            ),
            _RuleRow(
              text: 'Накопленные монеты доступны сразу после подтверждения предыдущего заказа.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _RuleCard(
          icon: Icons.all_inclusive_rounded,
          iconColor: AppColors.navy,
          title: 'Срок действия',
          children: [
            _RuleRow(
              text: rules.expiry.coinsExpire
                  ? 'YoCoin имеют срок действия. Уточняйте условия в приложении.'
                  : 'YoCoin не сгорают — накапливайте без ограничений по времени.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _RuleCard(
          icon: Icons.undo_rounded,
          iconColor: const Color(0xFFE05C2A),
          title: 'При возврате заказа',
          children: [
            _RuleRow(
              text:
                  'При отмене заказа начисленные за него YoCoin списываются. Использованные YoCoin возвращаются на баланс.',
            ),
          ],
        ),
        const SizedBox(height: 20),
        _TierTable(tiers: rules.tiers),
      ],
    );
  }
}

// ── Tier table ────────────────────────────────────────────────────────────────

class _TierTable extends StatelessWidget {
  const _TierTable({required this.tiers});

  final List<_Tier> tiers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Уровни лояльности',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.cardBorder,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < tiers.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, indent: 16, color: AppColors.border),
                _TierRow(tier: tiers[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TierRow extends StatelessWidget {
  const _TierRow({required this.tier});

  final _Tier tier;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String threshold;
    switch (tier.key) {
      case 'bronze':
        color = const Color(0xFFCD7F32);
        threshold = 'от ${_fmtAmount(tier.min)} ₸';
      case 'silver':
        color = const Color(0xFF9E9E9E);
        threshold = 'от ${_fmtAmount(tier.min)} ₸';
      case 'gold':
        color = const Color(0xFFF9B830);
        threshold = 'от ${_fmtAmount(tier.min)} ₸';
      default:
        color = AppColors.navyMuted;
        threshold = 'до ${_fmtAmount((tier.max ?? 0) + 1)} ₸';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier.label,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  threshold,
                  style: const TextStyle(
                    color: AppColors.navyMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${tier.discountPct}% кэшбэк',
                style: const TextStyle(
                  color: AppColors.purple,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (tier.freeDeliveryThreshold == 0)
                const Text(
                  'бесплатная доставка',
                  style: TextStyle(
                    color: Color(0xFF23804A),
                    fontSize: 11,
                  ),
                )
              else
                Text(
                  'доставка от ${_fmtAmount(tier.freeDeliveryThreshold)} ₸',
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

// ── Rule card ─────────────────────────────────────────────────────────────────

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
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
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(color: AppColors.navyMuted, fontSize: 13),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.navyMuted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
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

// ── Data models ───────────────────────────────────────────────────────────────

class _LoyaltyRules {
  const _LoyaltyRules({
    required this.accrual,
    required this.redemption,
    required this.expiry,
    required this.tiers,
  });

  final _Accrual accrual;
  final _Redemption redemption;
  final _Expiry expiry;
  final List<_Tier> tiers;

  factory _LoyaltyRules.fromJson(Map<String, dynamic> j) => _LoyaltyRules(
        accrual: _Accrual.fromJson(j['accrual'] as Map<String, dynamic>),
        redemption:
            _Redemption.fromJson(j['redemption'] as Map<String, dynamic>),
        expiry: _Expiry.fromJson(j['expiry'] as Map<String, dynamic>),
        tiers: (j['tiers'] as List)
            .whereType<Map<String, dynamic>>()
            .map(_Tier.fromJson)
            .toList(),
      );
}

class _Accrual {
  const _Accrual({required this.defaultPct, required this.minOrderAmount});
  final int defaultPct;
  final int minOrderAmount;
  factory _Accrual.fromJson(Map<String, dynamic> j) => _Accrual(
        defaultPct: (j['default_pct'] as num).toInt(),
        minOrderAmount: (j['min_order_amount'] as num).toInt(),
      );
}

class _Redemption {
  const _Redemption({required this.maxPctOfOrder});
  final int maxPctOfOrder;
  factory _Redemption.fromJson(Map<String, dynamic> j) => _Redemption(
        maxPctOfOrder: (j['max_pct_of_order'] as num).toInt(),
      );
}

class _Expiry {
  const _Expiry({required this.coinsExpire});
  final bool coinsExpire;
  factory _Expiry.fromJson(Map<String, dynamic> j) =>
      _Expiry(coinsExpire: j['coins_expire'] as bool? ?? false);
}

class _Tier {
  const _Tier({
    required this.key,
    required this.label,
    required this.min,
    this.max,
    required this.discountPct,
    required this.freeDeliveryThreshold,
  });
  final String key;
  final String label;
  final int min;
  final int? max;
  final int discountPct;
  final int freeDeliveryThreshold;

  factory _Tier.fromJson(Map<String, dynamic> j) => _Tier(
        key: j['key'] as String,
        label: j['label'] as String,
        min: (j['min'] as num).toInt(),
        max: j['max'] != null ? (j['max'] as num).toInt() : null,
        discountPct: (j['discount_pct'] as num).toInt(),
        freeDeliveryThreshold:
            (j['free_delivery_threshold'] as num).toInt(),
      );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmtBalance(int amount) {
  if (amount == 0) return '0';
  return amount.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]} ',
  );
}

String _fmtAmount(int amount) {
  return amount.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]} ',
  );
}
