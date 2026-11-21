import 'package:intl/intl.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/currency.dart';
import 'package:conduit/bridge_generated.dart/events.dart';
import 'package:conduit/widgets/amount_visibility.dart';

/// [sats] in the unit the home screen is showing amounts in: fiat at the
/// cached rate (sats until one is cached), otherwise sats. For compact rows
/// that list balances so they can be picked between. A hidden balance reads
/// as sats here rather than masked: opening a picker is asking to see what
/// the balances are, and a list of dots would answer nothing.
String formatDisplayedSats(
  BalanceDisplay display,
  ConduitClient client,
  int sats,
) {
  if (display == BalanceDisplay.fiat) {
    final fiat = client.satsToFiat(amountSats: sats);
    final currency = findFiatCurrency(code: client.currencyCode());

    if (fiat != null && currency != null) {
      return formatFiat(currency, fiat, symbolLast: true);
    }
  }

  return '${NumberFormat('#,###').format(sats)} sat';
}

/// Formats a fiat [amount] for the given [currency]. The symbol leads (e.g.
/// `$ 12.50`) for large displays and detail rows; pass [symbolLast] for the
/// trailing form (e.g. `12.50 $`) used by the compact payment cards.
String formatFiat(
  FiatCurrency currency,
  double amount, {
  bool symbolLast = false,
}) {
  final number = _formatFiatNumber(currency, amount);
  return symbolLast
      ? '$number ${currency.symbol}'
      : '${currency.symbol} $number';
}

String _formatFiatNumber(FiatCurrency currency, double amount) {
  final pattern =
      currency.decimalDigits > 0
          ? '#,##0.${'0' * currency.decimalDigits}'
          : '#,##0';
  return NumberFormat(pattern).format(amount);
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

/// Formats the fiat value frozen against [event] at payment time, returning the
/// currency name and the formatted amount. Unlike [cachedFiatAmount] this uses
/// the rate snapshotted when the payment landed — so history shows the value as
/// of the time of the payment — and returns `null` when no rate was recorded
/// (the payment predates the feature or landed with no fresh rate cached).
({String currency, String amount})? historicalFiat(
  ConduitPayment event, {
  bool symbolLast = false,
}) {
  final amount = event.fiatAmount;
  final code = event.fiatCurrencyCode;
  if (amount == null || code == null) return null;

  final currency = findFiatCurrency(code: code);
  if (currency == null) return null;

  return (
    currency: currency.name,
    amount: formatFiat(currency, amount, symbolLast: symbolLast),
  );
}

/// Splits the historical fiat value frozen against [event] into the formatted
/// number and its lowercase currency code (e.g. `usd`), for the two-line
/// trailing of the payment cards — keeping the unit consistent with `sat`.
/// Returns `null` when no rate was recorded for the payment.
({String number, String unit})? historicalFiatParts(ConduitPayment event) {
  final amount = event.fiatAmount;
  final code = event.fiatCurrencyCode;
  if (amount == null || code == null) return null;

  final currency = findFiatCurrency(code: code);
  if (currency == null) return null;

  return (
    number: _formatFiatNumber(currency, amount),
    unit: currency.code.toLowerCase(),
  );
}
