import 'package:conduit/bridge_generated.dart/events.dart';
import 'package:conduit/utils/history_csv.dart';
import 'package:flutter_test/flutter_test.dart';

ConduitPayment _payment({
  required String operationId,
  required bool incoming,
  required PaymentType type,
  required int amountSats,
  int? feeSats,
  required int timestamp,
  bool? success,
  String? txid,
  String? address,
  String? preimage,
  double? fiatAmount,
  String? fiatCurrencyCode,
}) {
  return ConduitPayment(
    operationId: operationId,
    incoming: incoming,
    paymentType: type,
    amountSats: amountSats,
    feeSats: feeSats,
    timestamp: timestamp,
    success: success,
    ecash: incoming ? null : 'notes-that-must-not-leak',
    txid: txid,
    preimage: preimage,
    address: address,
    fiatAmount: fiatAmount,
    fiatCurrencyCode: fiatCurrencyCode,
  );
}

void main() {
  test('rows are oldest first with credit, debit and fee split out', () {
    final csv = buildHistoryCsv(
      mint: 'Bitcoin Principles',
      account: 'savings',
      payments: [
        _payment(
          operationId: 'c4d2e0',
          incoming: false,
          type: PaymentType.bitcoin,
          amountSats: 100000,
          feeSats: 312,
          timestamp:
              DateTime.utc(2026, 11, 15, 18, 30, 5).millisecondsSinceEpoch,
          success: true,
          txid: '4e1f9d',
          address: 'bc1qexample',
          fiatAmount: 1649.20,
          fiatCurrencyCode: 'ZAR',
        ),
        _payment(
          operationId: '0a9b77',
          incoming: true,
          type: PaymentType.lightning,
          amountSats: 25000,
          timestamp:
              DateTime.utc(2026, 11, 15, 9, 12, 40).millisecondsSinceEpoch,
          success: true,
          preimage: '8f3ac1',
          fiatAmount: 412.30,
          fiatCurrencyCode: 'ZAR',
        ),
      ],
    );

    expect(
      csv,
      '$historyCsvHeader\r\n'
      '2026-11-15T09:12:40Z,25000,,,412.30,,,ZAR,'
      'Bitcoin Principles,savings,lightning,settled,,,8f3ac1,0a9b77\r\n'
      '2026-11-15T18:30:05Z,,100000,312,,1649.20,5.15,ZAR,'
      'Bitcoin Principles,savings,bitcoin,settled,4e1f9d,bc1qexample,,c4d2e0\r\n',
    );
  });

  test('a pending ecash send has no fiat, no proof and no notes', () {
    final csv = buildHistoryCsv(
      mint: 'Freedom One',
      account: 'primary',
      payments: [
        _payment(
          operationId: '19ffb3',
          incoming: false,
          type: PaymentType.ecash,
          amountSats: 5000,
          feeSats: 0,
          timestamp:
              DateTime.utc(2026, 11, 16, 7, 55, 13).millisecondsSinceEpoch,
        ),
      ],
    );

    expect(
      csv,
      '$historyCsvHeader\r\n'
      '2026-11-16T07:55:13Z,,5000,0,,,,,Freedom One,primary,ecash,pending,,,,19ffb3\r\n',
    );
    expect(csv.contains('notes-that-must-not-leak'), isFalse);
  });

  test('a mint name with a comma or quote is quoted', () {
    final csv = buildHistoryCsv(
      mint: 'Mint, "The" One',
      account: 'primary',
      payments: [
        _payment(
          operationId: 'aa',
          incoming: true,
          type: PaymentType.ecash,
          amountSats: 1,
          timestamp: 0,
          success: false,
        ),
      ],
    );

    expect(
      csv.split('\r\n')[1],
      '1970-01-01T00:00:00Z,1,,,,,,,"Mint, ""The"" One",primary,ecash,failed,,,,aa',
    );
  });
}
