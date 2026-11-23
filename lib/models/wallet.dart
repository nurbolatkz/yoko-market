import 'loyalty.dart';

/// «Мой кошелёк»: gift balance (paid money, ₸) and YoCoin (bonus) are kept
/// separately — see API_CONTRACT.md `GET /wallet`.
class Wallet {
  const Wallet({
    required this.giftBalance,
    required this.giftExpiresAt,
    required this.yocoinBalance,
    required this.cashback,
  });

  final int giftBalance;
  final DateTime? giftExpiresAt;
  final int yocoinBalance;
  final MonthlyCashback? cashback;

  factory Wallet.fromJson(Map<String, dynamic> j) => Wallet(
        giftBalance: (j['gift_balance'] as num?)?.toInt() ?? 0,
        giftExpiresAt: DateTime.tryParse(j['gift_expires_at'] as String? ?? ''),
        yocoinBalance: (j['yocoin_balance'] as num?)?.toInt() ?? 0,
        cashback: j['cashback'] is Map<String, dynamic>
            ? MonthlyCashback.fromJson(j['cashback'] as Map<String, dynamic>)
            : null,
      );
}

enum WalletTxKind { gift, yocoin }

class WalletTx {
  const WalletTx({
    required this.id,
    required this.kind,
    required this.amount,
    required this.reason,
    required this.title,
    required this.createdAt,
  });

  final int id;
  final WalletTxKind kind;

  /// Positive = credit, negative = debit.
  final int amount;

  /// e.g. `gift_card_activated`, `order_payment`, `monthly_cashback`,
  /// `referral_reward`, `registration_bonus`, `birthday_bonus`, `expired`.
  final String reason;
  final String title;
  final DateTime createdAt;

  bool get isCredit => amount > 0;

  factory WalletTx.fromJson(Map<String, dynamic> j) => WalletTx(
        id: (j['id'] as num).toInt(),
        kind: j['kind'] == 'gift' ? WalletTxKind.gift : WalletTxKind.yocoin,
        amount: (j['amount'] as num).toInt(),
        reason: j['reason'] as String? ?? '',
        title: j['title'] as String? ?? '',
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class WalletHistoryPage {
  const WalletHistoryPage({required this.items, required this.nextCursor});

  final List<WalletTx> items;

  /// Null when there are no more pages.
  final int? nextCursor;

  factory WalletHistoryPage.fromJson(Map<String, dynamic> j) =>
      WalletHistoryPage(
        items: (j['items'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(WalletTx.fromJson)
            .toList(),
        nextCursor: (j['next_cursor'] as num?)?.toInt(),
      );
}

class GiftCardActivation {
  const GiftCardActivation({
    required this.amount,
    required this.giftBalance,
    required this.expiresAt,
    this.fromName,
    this.message,
  });

  final int amount;
  final int giftBalance;
  final DateTime? expiresAt;
  final String? fromName;
  final String? message;

  factory GiftCardActivation.fromJson(Map<String, dynamic> j) =>
      GiftCardActivation(
        amount: (j['amount'] as num).toInt(),
        giftBalance: (j['gift_balance'] as num?)?.toInt() ?? 0,
        expiresAt: DateTime.tryParse(j['expires_at'] as String? ?? ''),
        fromName: j['from_name'] as String?,
        message: j['message'] as String?,
      );
}

class SentGiftCard {
  const SentGiftCard({
    required this.id,
    required this.amount,
    required this.recipientLabel,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final int amount;
  final String recipientLabel;

  /// `issued` | `sold` | `activated` | `partially_used` | `used` |
  /// `expired` | `blocked`.
  final String status;
  final DateTime createdAt;

  factory SentGiftCard.fromJson(Map<String, dynamic> j) => SentGiftCard(
        id: (j['id'] as num).toInt(),
        amount: (j['amount'] as num).toInt(),
        recipientLabel: j['recipient_label'] as String? ?? '',
        status: j['status'] as String? ?? '',
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// Gift-card activation failures, with the Russian UI text from the contract.
enum GiftCardError {
  invalidCode('invalid_code', 'Карта не найдена — проверьте код'),
  alreadyActivated('already_activated', 'Карта уже активирована'),
  notSold('not_sold', 'Карта ещё не активна — обратитесь к продавцу'),
  expired('expired', 'Срок действия карты истёк'),
  blocked('blocked', 'Карта заблокирована'),
  tooManyAttempts(
    'too_many_attempts',
    'Слишком много попыток, попробуйте через час',
  ),
  unknown('unknown', 'Не удалось активировать карту. Попробуйте ещё раз');

  const GiftCardError(this.code, this.message);

  final String code;
  final String message;

  static GiftCardError fromCode(String? code) => GiftCardError.values
      .firstWhere((e) => e.code == code, orElse: () => GiftCardError.unknown);
}

class GiftCardException implements Exception {
  const GiftCardException(this.error);

  final GiftCardError error;

  @override
  String toString() => 'GiftCardException(${error.code})';
}
