import 'package:flutter/widgets.dart';
import '../theme/app_theme.dart';

/// Formats monetary amount as "5 990 ₸".
String formatMoney(int amount) => '${formatNumber(amount)} ₸';

/// Groups thousands: 1250 → "1 250", -6400 → "-6 400".
String formatNumber(int value) {
  final s = value.abs().toString();
  final buf = StringBuffer();
  final len = s.length;
  for (var i = 0; i < len; i++) {
    if (i > 0 && (len - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return value < 0 ? '-$buf' : buf.toString();
}

/// 2027-11-23 → "23.11.2027".
String formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

/// Russian plural: pluralRu(7, 'день', 'дня', 'дней') → "дней".
String pluralRu(int n, String one, String few, String many) {
  final n10 = n.abs() % 10;
  final n100 = n.abs() % 100;
  if (n10 == 1 && n100 != 11) return one;
  if (n10 >= 2 && n10 <= 4 && (n100 < 12 || n100 > 14)) return few;
  return many;
}

/// Inline money text widget.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amount, {
    super.key,
    this.style,
    this.color,
    this.size,
    this.weight = FontWeight.w800,
  });

  final int amount;
  final TextStyle? style;
  final Color? color;
  final double? size;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final base = style ??
        TextStyle(
          fontFamily: 'NunitoSans',
          fontWeight: weight,
          fontSize: size ?? 18,
          color: color ?? AppColors.navy,
        );
    return Text(formatMoney(amount), style: base);
  }
}
