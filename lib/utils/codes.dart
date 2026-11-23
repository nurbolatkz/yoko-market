/// Helpers for the short codes users type by hand: the 4-character friend
/// (referral) code and the 12-character gift-card code. See API_CONTRACT.md.
///
/// Alphabet excludes look-alikes O 0 I 1 L, so codes are easy to dictate.
abstract final class Codes {
  static const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const referralLength = 4;
  static const giftCardLength = 12;

  // Cyrillic letters that look like Latin ones on a phone keyboard.
  static const _cyrillicToLatin = {
    'А': 'A', 'В': 'B', 'С': 'C', 'Е': 'E', 'Н': 'H', 'К': 'K',
    'М': 'M', 'Р': 'P', 'Т': 'T', 'Х': 'X', 'У': 'Y',
  };

  /// Upper-cases, maps Cyrillic look-alikes to Latin and drops spaces/dashes.
  static String normalize(String input) {
    final buf = StringBuffer();
    for (final ch in input.toUpperCase().split('')) {
      if (ch == ' ' || ch == '-' || ch == ' ') continue;
      buf.write(_cyrillicToLatin[ch] ?? ch);
    }
    return buf.toString();
  }

  static bool _inAlphabet(String s) => s.split('').every(alphabet.contains);

  static bool isReferralCode(String input) {
    final c = normalize(input);
    return c.length == referralLength && _inAlphabet(c);
  }

  static bool isGiftCardCode(String input) {
    final c = normalize(input);
    return c.length == giftCardLength && _inAlphabet(c);
  }

  /// `K7QM29XTH4PB` → `K7QM-29XT-H4PB` (input may already contain dashes).
  static String formatGiftCard(String input) {
    final c = normalize(input);
    final parts = <String>[];
    for (var i = 0; i < c.length; i += 4) {
      parts.add(c.substring(i, i + 4 > c.length ? c.length : i + 4));
    }
    return parts.join('-');
  }
}
