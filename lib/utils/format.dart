import 'package:flutter/widgets.dart';
import '../theme/app_theme.dart';

/// Formats monetary amount as "5 990 ₸" (non-breaking space as thousands separator).
String formatMoney(int amount) {
  final s = amount.abs().toString();
  final buf = StringBuffer();
  final len = s.length;
  for (var i = 0; i < len; i++) {
    if (i > 0 && (len - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  if (amount < 0) return '-${buf.toString()} ₸';
  return '${buf.toString()} ₸';
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
