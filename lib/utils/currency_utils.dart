import 'package:intl/intl.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/currency.dart';

/// Formats a fiat [amount] for the given [currency], e.g. `$ 12.50`.
String formatFiat(FiatCurrency currency, double amount) {
  final pattern =
      currency.decimalDigits > 0
          ? '#,##0.${'0' * currency.decimalDigits}'
          : '#,##0';
  return '${currency.symbol} ${NumberFormat(pattern).format(amount)}';
}

/// Converts [amountSats] to the user's fiat currency using the cached exchange
/// rate, without triggering a network fetch. Returns the currency name and the
/// formatted amount, or `null` when no rate has been cached yet.
({String currency, String amount})? cachedFiatAmount(
  ConduitClient client,
  int amountSats,
) {
  final fiat = client.satsToFiat(amountSats: amountSats);
  if (fiat == null) return null;

  final currency = findFiatCurrency(code: client.currencyCode())!;
  return (currency: currency.name, amount: formatFiat(currency, fiat));
}
