import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/loyalty.dart';
import '../models/wallet.dart';
import '../utils/codes.dart';
import 'api_client.dart';
import 'loyalty_api.dart';

/// «Мой кошелёк»: gift balance, YoCoin, monthly cashback, history and
/// gift-card activation. See API_CONTRACT.md (`/wallet`, `/gift-cards/*`).
///
/// Implementation is picked by `--dart-define=MOCK_WALLET` (default `true`
/// until the backend is ready).
abstract class WalletApi {
  factory WalletApi() =>
      AppConfig.mockWallet ? MockWalletApi.shared : HttpWalletApi();

  Future<Wallet> getWallet(String token);

  Future<WalletHistoryPage> getHistory(
    String token, {
    int? cursor,
    int limit = 20,
  });

  /// Throws [GiftCardException] with a user-facing [GiftCardError].
  Future<GiftCardActivation> activateGiftCard(String token, String code);

  Future<List<SentGiftCard>> getSentGiftCards(String token);
}

class HttpWalletApi implements WalletApi {
  HttpWalletApi({Dio? dio}) : _dio = dio ?? ApiClient.create();

  final Dio _dio;

  @override
  Future<Wallet> getWallet(String token) async {
    final resp = await _dio.get<dynamic>(
      '/wallet',
      options: ApiClient.bearer(token),
    );
    return Wallet.fromJson(resp.data as Map<String, dynamic>);
  }

  @override
  Future<WalletHistoryPage> getHistory(
    String token, {
    int? cursor,
    int limit = 20,
  }) async {
    final resp = await _dio.get<dynamic>(
      '/wallet/history',
      queryParameters: {'cursor': ?cursor, 'limit': limit},
      options: ApiClient.bearer(token),
    );
    return WalletHistoryPage.fromJson(resp.data as Map<String, dynamic>);
  }

  @override
  Future<GiftCardActivation> activateGiftCard(String token, String code) async {
    try {
      final resp = await _dio.post<dynamic>(
        '/gift-cards/activate',
        data: {'code': Codes.formatGiftCard(code)},
        options: ApiClient.bearer(token),
      );
      return GiftCardActivation.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 429) {
        throw const GiftCardException(GiftCardError.tooManyAttempts);
      }
      final data = e.response?.data;
      if (status == 400 && data is Map) {
        throw GiftCardException(
          GiftCardError.fromCode(data['detail'] as String?),
        );
      }
      rethrow; // network / 401 / 5xx — handled by the caller's ErrorState
    }
  }

  @override
  Future<List<SentGiftCard>> getSentGiftCards(String token) async {
    final resp = await _dio.get<dynamic>(
      '/gift-cards/sent',
      options: ApiClient.bearer(token),
    );
    return (resp.data as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SentGiftCard.fromJson)
        .toList();
  }
}

/// In-memory stand-in for the backend, shared across screens so an
/// activation in one place shows up everywhere. 500 ms latency (AGENTS.md).
///
/// Demo codes (dashes and Cyrillic look-alikes are accepted):
/// - `K7QM-29XT-H4PB` → 20 000 ₸ from «Асель»
/// - `DEMA-5555-CARD` → 5 000 ₸
/// - `USED-USED-USED` → already activated
/// - `EXPD-EXPD-EXPD` → expired
/// - any other code → not found; 5 failures → too many attempts
class MockWalletApi implements WalletApi {
  MockWalletApi({
    this.delay = const Duration(milliseconds: 500),
    DateTime Function()? clock,
    LoyaltyRules? rules,
  })  : _clock = clock ?? DateTime.now,
        _rules = rules ?? MockLoyaltyApi.rules {
    _seedHistory();
  }

  static final shared = MockWalletApi();

  final Duration delay;
  final DateTime Function() _clock;
  final LoyaltyRules _rules;

  static const maxFailedAttempts = 5;
  static const _monthSpent = 62500;

  static const _cards = <String, (int, String?, String?)>{
    'K7QM29XTH4PB': (20000, 'Асель', 'С днём рождения малыша!'),
    'DEMA5555CARD': (5000, null, null),
  };

  int _giftBalance = 0;
  DateTime? _giftExpiresAt;
  final int _yocoinBalance = 1250;
  int _failedAttempts = 0;
  int _nextId = 100;
  final Set<String> _activated = {'USEDUSEDUSED'};
  final List<WalletTx> _history = [];

  void _seedHistory() {
    final now = _clock();
    _history.addAll([
      WalletTx(
        id: _nextId++,
        kind: WalletTxKind.yocoin,
        amount: 140,
        reason: 'monthly_cashback',
        title: 'Кэшбэк за прошлый месяц',
        createdAt: DateTime(now.year, now.month, 1, 0, 5),
      ),
      WalletTx(
        id: _nextId++,
        kind: WalletTxKind.yocoin,
        amount: 300,
        reason: 'referral_reward',
        title: 'Друг сделал первый заказ',
        createdAt: now.subtract(const Duration(days: 9)),
      ),
      WalletTx(
        id: _nextId++,
        kind: WalletTxKind.yocoin,
        amount: 1000,
        reason: 'registration_bonus',
        title: 'Бонус за регистрацию',
        createdAt: now.subtract(const Duration(days: 30)),
      ),
    ]);
    _history.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<Wallet> getWallet(String token) async {
    await Future<void>.delayed(delay);
    return Wallet(
      giftBalance: _giftBalance,
      giftExpiresAt: _giftExpiresAt,
      yocoinBalance: _yocoinBalance,
      cashback: _cashback(),
    );
  }

  /// What the server would compute for the current month.
  MonthlyCashback _cashback() {
    final now = _clock();
    final tiers = _rules.tiers;
    final reached = tiers.where((t) => t.minMonthlySpend <= _monthSpent);
    final current = reached.isEmpty ? null : reached.last;
    final upcoming = tiers.where((t) => t.minMonthlySpend > _monthSpent);
    final next = upcoming.isEmpty ? null : upcoming.first;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final percent = current?.percent ?? 0;
    return MonthlyCashback(
      monthLabel: _months[now.month - 1],
      monthSpent: _monthSpent,
      currentPercent: percent,
      nextPercent: next?.percent,
      nextThreshold: next?.minMonthlySpend,
      leftToNext: next == null ? 0 : next.minMonthlySpend - _monthSpent,
      daysLeft: daysInMonth - now.day,
      previewAmount: _monthSpent * percent ~/ 100,
    );
  }

  @override
  Future<WalletHistoryPage> getHistory(
    String token, {
    int? cursor,
    int limit = 20,
  }) async {
    await Future<void>.delayed(delay);
    final start = cursor == null
        ? 0
        : _history.indexWhere((t) => t.id == cursor).clamp(0, _history.length);
    final end = (start + limit).clamp(0, _history.length);
    return WalletHistoryPage(
      items: _history.sublist(start, end),
      nextCursor: end < _history.length ? _history[end].id : null,
    );
  }

  @override
  Future<GiftCardActivation> activateGiftCard(String token, String code) async {
    await Future<void>.delayed(delay);
    if (_failedAttempts >= maxFailedAttempts) {
      throw const GiftCardException(GiftCardError.tooManyAttempts);
    }
    final c = Codes.normalize(code);
    GiftCardError? error;
    if (_activated.contains(c)) {
      error = GiftCardError.alreadyActivated;
    } else if (c == 'EXPDEXPDEXPD') {
      error = GiftCardError.expired;
    } else if (!Codes.isGiftCardCode(c) || !_cards.containsKey(c)) {
      error = GiftCardError.invalidCode;
    }
    if (error != null) {
      _failedAttempts++;
      throw GiftCardException(error);
    }

    final (amount, fromName, message) = _cards[c]!;
    final now = _clock();
    _activated.add(c);
    _giftBalance += amount;
    _giftExpiresAt = DateTime(now.year + 1, now.month, now.day);
    _history.insert(
      0,
      WalletTx(
        id: _nextId++,
        kind: WalletTxKind.gift,
        amount: amount,
        reason: 'gift_card_activated',
        title: fromName != null ? 'Подарок от $fromName' : 'Подарочная карта',
        createdAt: now,
      ),
    );
    return GiftCardActivation(
      amount: amount,
      giftBalance: _giftBalance,
      expiresAt: _giftExpiresAt,
      fromName: fromName,
      message: message,
    );
  }

  @override
  Future<List<SentGiftCard>> getSentGiftCards(String token) async {
    await Future<void>.delayed(delay);
    return [
      SentGiftCard(
        id: 314,
        amount: 10000,
        recipientLabel: '+7 701 ••• 45 67',
        status: 'activated',
        createdAt: _clock().subtract(const Duration(days: 3)),
      ),
    ];
  }

  static const _months = [
    'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
    'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
  ];
}
