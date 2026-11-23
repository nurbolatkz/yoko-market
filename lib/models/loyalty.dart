/// Loyalty programme rules (AGENTS.md §9 — Figma is the source of truth).
///
/// Cashback is monthly: the total of a calendar month's purchases picks the
/// tier, and YoCoin are credited after the month ends. 1 YoCoin = 1 ₸.
/// Screens must render these numbers, never hardcode them.
class LoyaltyRules {
  const LoyaltyRules({
    required this.tiers,
    required this.maxPayWithBonusPct,
    required this.registrationBonus,
    required this.referralBonus,
    required this.freeDeliveryThreshold,
  });

  /// Sorted ascending by [CashbackTier.minMonthlySpend].
  final List<CashbackTier> tiers;

  /// Up to how many percent of an order can be paid with YoCoin.
  final int maxPayWithBonusPct;

  /// YoCoin for signing up.
  final int registrationBonus;

  /// YoCoin for each invited friend.
  final int referralBonus;

  /// Free delivery from this order amount (₸), inside the delivery zone.
  final int freeDeliveryThreshold;

  /// Highest cashback percent available (e.g. «до 10% кэшбэка»).
  int get maxPercent => tiers.isEmpty ? 0 : tiers.last.percent;

  /// Accepts the new contract shape and the legacy `/loyalty/rules` shape
  /// (`tiers[].min` / `discount_pct`, `redemption.max_pct_of_order`).
  factory LoyaltyRules.fromJson(Map<String, dynamic> j) {
    final redemption = j['redemption'];
    final tiers = (j['tiers'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CashbackTier.fromJson)
        .toList()
      ..sort((a, b) => a.minMonthlySpend.compareTo(b.minMonthlySpend));
    return LoyaltyRules(
      tiers: tiers,
      maxPayWithBonusPct: _int(j['max_pay_with_bonus_pct']) ??
          (redemption is Map ? _int(redemption['max_pct_of_order']) : null) ??
          100,
      registrationBonus: _int(j['registration_bonus']) ?? 0,
      referralBonus: _int(j['referral_bonus']) ?? 0,
      freeDeliveryThreshold: _int(j['free_delivery_threshold']) ??
          (tiers.isNotEmpty ? tiers.first.freeDeliveryThreshold : null) ??
          0,
    );
  }
}

class CashbackTier {
  const CashbackTier({
    required this.minMonthlySpend,
    required this.percent,
    this.label = '',
    this.freeDeliveryThreshold,
  });

  /// Monthly purchase total (₸) from which this tier applies.
  final int minMonthlySpend;
  final int percent;
  final String label;

  /// Only present in the legacy shape.
  final int? freeDeliveryThreshold;

  factory CashbackTier.fromJson(Map<String, dynamic> j) => CashbackTier(
        minMonthlySpend: _int(j['min_monthly_spend']) ?? _int(j['min']) ?? 0,
        percent: _int(j['percent']) ?? _int(j['discount_pct']) ?? 0,
        label: j['label'] as String? ?? '',
        freeDeliveryThreshold: _int(j['free_delivery_threshold']),
      );
}

/// Preliminary cashback for the current calendar month («предварительный»
/// until credited after the month ends). Computed by the server.
class MonthlyCashback {
  const MonthlyCashback({
    required this.monthLabel,
    required this.monthSpent,
    required this.currentPercent,
    required this.nextPercent,
    required this.nextThreshold,
    required this.leftToNext,
    required this.daysLeft,
    required this.previewAmount,
  });

  final String monthLabel;
  final int monthSpent;
  final int currentPercent;

  /// Null when the top tier is already reached.
  final int? nextPercent;
  final int? nextThreshold;
  final int leftToNext;
  final int daysLeft;

  /// YoCoin expected after the month closes.
  final int previewAmount;

  bool get isTopTier => nextPercent == null;

  /// 0..1 progress towards [nextThreshold], for the progress bar.
  double get progress {
    final next = nextThreshold;
    if (next == null || next <= 0) return 1;
    return (monthSpent / next).clamp(0.0, 1.0);
  }

  factory MonthlyCashback.fromJson(Map<String, dynamic> j) => MonthlyCashback(
        monthLabel: j['month_label'] as String? ?? '',
        monthSpent: _int(j['month_spent']) ?? 0,
        currentPercent: _int(j['current_percent']) ?? 0,
        nextPercent: _int(j['next_percent']),
        nextThreshold: _int(j['next_threshold']),
        leftToNext: _int(j['left_to_next']) ?? 0,
        daysLeft: _int(j['days_left']) ?? 0,
        previewAmount: _int(j['preview_amount']) ?? 0,
      );
}

int? _int(dynamic v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);
