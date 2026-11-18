import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String monthChartMoney(BuildContext context, int cents, String currency) =>
    NumberFormat.currency(
      locale: Localizations.localeOf(context).toString(),
      symbol: currency,
      decimalDigits: 2,
    ).format(cents / 100);

Color investmentChartColor(String type) => switch (type) {
  'etf' => const Color(0xFF5B9EEF),
  'stock' => const Color(0xFFAB83DE),
  'crypto' => const Color(0xFFE9B844),
  'bond' => const Color(0xFF66AE92),
  _ => const Color(0xFF8794A2),
};

Color readableChartColor(BuildContext context, Color color) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (dark && color.computeLuminance() < .14)
    return Color.lerp(color, Colors.white, .35)!;
  if (!dark && color.computeLuminance() > .8)
    return Color.lerp(color, Colors.black, .25)!;
  return color;
}
