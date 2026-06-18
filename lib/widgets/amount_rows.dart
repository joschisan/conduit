import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/utils/currency_utils.dart';
import 'package:conduit/widgets/detail_row_widget.dart';

/// Builds the amount rows for a bordered detail list: always an "Amount in
/// Bitcoin" row, followed by an "Amount in `<currency>`" row when a cached
/// exchange rate is available.
///
/// The fiat row is converted from the cached rate without triggering a network
/// fetch, and is omitted entirely (rather than left as an empty cell) when no
/// rate has been cached yet.
List<Widget> amountRows({
  required ConduitClient client,
  required int amountSats,
}) {
  final rows = <Widget>[
    DetailRow(
      icon: PhosphorIconsRegular.currencyBtc,
      label: 'Amount in Bitcoin',
      value: '${NumberFormat('#,###').format(amountSats)} sat',
    ),
  ];

  final fiat = cachedFiatAmount(client, amountSats);
  if (fiat != null) {
    rows.add(
      DetailRow(
        icon: PhosphorIconsRegular.currencyDollar,
        label: 'Amount in ${fiat.currency}',
        value: fiat.amount,
      ),
    );
  }

  return rows;
}
