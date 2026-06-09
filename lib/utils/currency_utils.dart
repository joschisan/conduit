import 'package:intl/intl.dart';
import 'package:conduit/bridge_generated.dart/currency.dart';

/// Formats a fiat [amount] for the given [currency], e.g. `$ 12.50`.
String formatFiat(FiatCurrency currency, double amount) {
  final pattern =
      currency.decimalDigits > 0
          ? '#,##0.${'0' * currency.decimalDigits}'
          : '#,##0';
  return '${currency.symbol} ${NumberFormat(pattern).format(amount)}';
}
