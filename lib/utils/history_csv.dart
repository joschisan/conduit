import 'package:conduit/bridge_generated.dart/events.dart';

/// A payment history as CSV, oldest row first. Takes the list as the history
/// screen shows it, so whatever filter is up there is what gets exported.
///
/// The layout is the double-entry one bookkeeping imports expect, as Blink's
/// export has it: a credit column and a debit column rather than a signed
/// amount, the fee on its own, and the same split again in the fiat currency
/// the app showed at the time. The mint and account ride along on every row
/// so exports from several accounts can be stacked in one sheet. Sent ecash
/// notes are left out on purpose: a note is the money until it is claimed,
/// and a CSV ends up in mail.
const historyCsvHeader =
    'timestamp,credit_sats,debit_sats,fee_sats,'
    'fiat_credit,fiat_debit,fiat_fee,fiat_currency,'
    'mint,account,type,status,txid,address,preimage,operation_id';

String buildHistoryCsv({
  required String mint,
  required String account,
  required List<ConduitPayment> payments,
}) {
  final sorted = [...payments]
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  final lines = [
    historyCsvHeader,
    for (final payment in sorted) _row(mint, account, payment),
  ];

  return '${lines.join('\r\n')}\r\n';
}

String _row(String mint, String account, ConduitPayment payment) {
  final amount = payment.amountSats;
  final fee = payment.feeSats;
  final fiat = payment.fiatAmount;

  // The fee at the rate the amount was snapshotted at: there is no second
  // snapshot for the fee, and the two were worth the same per sat.
  final fiatFee =
      fiat != null && fee != null && amount > 0 ? fiat * fee / amount : null;

  final status = switch (payment.success) {
    null => 'pending',
    true => 'settled',
    false => 'failed',
  };

  final type = switch (payment.paymentType) {
    PaymentType.lightning => 'lightning',
    PaymentType.bitcoin => 'bitcoin',
    PaymentType.ecash => 'ecash',
  };

  return [
    _timestamp(payment.timestamp),
    payment.incoming ? '$amount' : '',
    payment.incoming ? '' : '$amount',
    fee == null ? '' : '$fee',
    payment.incoming ? _fiat(fiat) : '',
    payment.incoming ? '' : _fiat(fiat),
    _fiat(fiatFee),
    payment.fiatCurrencyCode ?? '',
    mint,
    account,
    type,
    status,
    payment.txid ?? '',
    payment.address ?? '',
    payment.preimage ?? '',
    payment.operationId,
  ].map(_quote).join(',');
}

/// ISO 8601 in UTC to the second, the form every spreadsheet parses.
String _timestamp(int millis) {
  final time = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  return '${time.toIso8601String().substring(0, 19)}Z';
}

String _fiat(double? value) => value == null ? '' : value.toStringAsFixed(2);

/// RFC 4180: a field holding a comma, a quote or a line break is wrapped in
/// quotes, with quotes inside doubled. Only the mint name can need it.
String _quote(String field) {
  if (!field.contains(RegExp(r'[",\r\n]'))) return field;
  return '"${field.replaceAll('"', '""')}"';
}
