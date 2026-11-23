import 'package:flutter_test/flutter_test.dart';
import 'package:yokomarket/models/loyalty.dart';
import 'package:yokomarket/models/wallet.dart';
import 'package:yokomarket/services/loyalty_api.dart';
import 'package:yokomarket/services/wallet_api.dart';
import 'package:yokomarket/utils/codes.dart';

void main() {
  group('LoyaltyRules.fromJson', () {
    test('new contract shape (Figma monthly cashback)', () {
      final r = LoyaltyRules.fromJson(MockLoyaltyApi.rulesJson);
      expect(r.tiers.map((t) => (t.minMonthlySpend, t.percent)), [
        (50000, 3),
        (100000, 5),
        (200000, 10),
      ]);
      expect(r.maxPercent, 10);
      expect(r.maxPayWithBonusPct, 100);
      expect(r.registrationBonus, 1000);
      expect(r.referralBonus, 300);
      expect(r.freeDeliveryThreshold, 10000);
    });

    test('legacy /loyalty/rules shape still parses', () {
      final r = LoyaltyRules.fromJson({
        'accrual': {'default_pct': 2, 'min_order_amount': 0},
        'redemption': {'max_pct_of_order': 50},
        'expiry': {'coins_expire': false},
        'tiers': [
          {
            'key': 'silver', 'label': 'Серебро', 'min': 100000,
            'max': null, 'discount_pct': 5, 'free_delivery_threshold': 8000,
          },
          {
            'key': 'new', 'label': 'Новичок', 'min': 0, 'max': 99999,
            'discount_pct': 2, 'free_delivery_threshold': 10000,
          },
        ],
      });
      expect(r.tiers.first.label, 'Новичок'); // sorted ascending
      expect(r.maxPercent, 5);
      expect(r.maxPayWithBonusPct, 50);
      expect(r.freeDeliveryThreshold, 10000);
    });
  });

  group('MonthlyCashback', () {
    test('progress and top tier', () {
      final c = MonthlyCashback.fromJson({
        'month_spent': 62500, 'current_percent': 3, 'next_percent': 5,
        'next_threshold': 100000, 'left_to_next': 37500,
      });
      expect(c.progress, closeTo(0.625, 1e-9));
      expect(c.isTopTier, isFalse);
      final top = MonthlyCashback.fromJson({
        'month_spent': 250000, 'current_percent': 10,
      });
      expect(top.isTopTier, isTrue);
      expect(top.progress, 1);
    });
  });

  group('Codes', () {
    test('normalize handles case, dashes, spaces and Cyrillic look-alikes', () {
      expect(Codes.normalize('daul'), 'DAUL');
      expect(Codes.normalize('k7qm-29xt h4pb'), 'K7QM29XTH4PB');
      expect(Codes.normalize('САЕК'), 'CAEK'); // Cyrillic С А Е К
    });

    test('referral code is 4 chars from the safe alphabet', () {
      expect(Codes.isReferralCode('DAUL'), isFalse); // L excluded
      expect(Codes.isReferralCode('DAUK'), isTrue);
      expect(Codes.isReferralCode('ДAUK'), isFalse); // Д has no Latin twin
      expect(Codes.isReferralCode('AB0C'), isFalse); // 0 excluded
      expect(Codes.isReferralCode('ABC'), isFalse);
    });

    test('gift card code: 12 chars, formatted in groups of 4', () {
      expect(Codes.isGiftCardCode('K7QM-29XT-H4PB'), isTrue);
      expect(Codes.isGiftCardCode('K7QM-29XT-H4P'), isFalse);
      expect(Codes.formatGiftCard('k7qm29xth4pb'), 'K7QM-29XT-H4PB');
    });
  });

  group('MockWalletApi', () {
    late MockWalletApi api;
    final now = DateTime(2026, 11, 23, 12);

    setUp(() => api = MockWalletApi(delay: Duration.zero, clock: () => now));

    test('wallet: separate balances and server-style cashback', () async {
      final w = await api.getWallet('t');
      expect(w.giftBalance, 0);
      expect(w.yocoinBalance, 1250);
      final c = w.cashback!;
      expect(c.monthLabel, 'Ноябрь');
      expect(c.currentPercent, 3);
      expect(c.nextPercent, 5);
      expect(c.leftToNext, 37500);
      expect(c.daysLeft, 7); // 30 − 23
      expect(c.previewAmount, 1875); // 3 % of 62 500
    });

    test('activation credits the gift balance and history', () async {
      final a = await api.activateGiftCard('t', 'k7qm-29xt-h4pb');
      expect(a.amount, 20000);
      expect(a.fromName, 'Асель');
      expect(a.expiresAt, DateTime(2027, 11, 23));

      final w = await api.getWallet('t');
      expect(w.giftBalance, 20000);
      final h = await api.getHistory('t');
      expect(h.items.first.kind, WalletTxKind.gift);
      expect(h.items.first.amount, 20000);
      expect(h.items.first.title, 'Подарок от Асель');
    });

    test('the same card cannot be activated twice', () async {
      await api.activateGiftCard('t', 'DEMA5555CARD');
      expect(
        () => api.activateGiftCard('t', 'DEMA-5555-CARD'),
        throwsA(isA<GiftCardException>().having(
          (e) => e.error, 'error', GiftCardError.alreadyActivated)),
      );
    });

    test('error codes map to contract errors', () async {
      Future<GiftCardError> errorFor(String code) async {
        try {
          await api.activateGiftCard('t', code);
        } on GiftCardException catch (e) {
          return e.error;
        }
        fail('expected GiftCardException for $code');
      }

      expect(await errorFor('USED-USED-USED'), GiftCardError.alreadyActivated);
      expect(await errorFor('EXPD-EXPD-EXPD'), GiftCardError.expired);
      expect(await errorFor('ABCD-EFGH-JKMN'), GiftCardError.invalidCode);
      expect(GiftCardError.invalidCode.message, 'Карта не найдена — проверьте код');
    });

    test('5 failed attempts lock activation, even for a valid code', () async {
      for (var i = 0; i < MockWalletApi.maxFailedAttempts; i++) {
        await expectLater(
          api.activateGiftCard('t', 'ABCD-EFGH-JKMN'),
          throwsA(isA<GiftCardException>()),
        );
      }
      expect(
        () => api.activateGiftCard('t', 'K7QM-29XT-H4PB'),
        throwsA(isA<GiftCardException>().having(
          (e) => e.error, 'error', GiftCardError.tooManyAttempts)),
      );
    });

    test('history pagination via cursor', () async {
      final first = await api.getHistory('t', limit: 2);
      expect(first.items, hasLength(2));
      expect(first.nextCursor, isNotNull);
      final second = await api.getHistory('t', cursor: first.nextCursor);
      expect(second.items, hasLength(1));
      expect(second.nextCursor, isNull);
    });
  });

  test('GiftCardError.fromCode falls back to unknown', () {
    expect(GiftCardError.fromCode('blocked'), GiftCardError.blocked);
    expect(GiftCardError.fromCode('weird'), GiftCardError.unknown);
    expect(GiftCardError.fromCode(null), GiftCardError.unknown);
  });
}
