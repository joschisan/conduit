import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/currency.dart';
import 'package:conduit/utils/currency_utils.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/detail_row_widget.dart';
import 'package:conduit/widgets/animated_entry_widget.dart';

/// A bordered list showing the amount in Bitcoin and, once the exchange rate
/// has been fetched, the converted fiat amount as a second row that animates
/// in the same way as newly arriving payments.
class AmountDetailList extends StatefulWidget {
  final ConduitClient client;
  final int amountSats;

  const AmountDetailList({
    super.key,
    required this.client,
    required this.amountSats,
  });

  @override
  State<AmountDetailList> createState() => _AmountDetailListState();
}

class _AmountDetailListState extends State<AmountDetailList> {
  late final FiatCurrency? _currency = findFiatCurrency(
    code: widget.client.currencyCode(),
  );
  String? _fiat;

  @override
  void initState() {
    super.initState();
    _fetchFiat();
  }

  Future<void> _fetchFiat() async {
    final currency = _currency;
    if (currency == null) return;

    try {
      final amount = await widget.client.satsToFiat(
        amountSats: widget.amountSats,
      );

      if (!mounted) return;

      setState(() => _fiat = formatFiat(currency, amount));
    } catch (_) {
      // Leave the fiat row hidden if the rate can't be fetched.
    }
  }

  @override
  Widget build(BuildContext context) {
    return BorderedList.column(
      children: [
        DetailRow(
          icon: PhosphorIconsRegular.currencyBtc,
          label: 'Amount in Bitcoin',
          value: '${NumberFormat('#,###').format(widget.amountSats)} sat',
        ),
        if (_fiat != null)
          AnimatedEntry(
            child: DetailRow(
              icon: PhosphorIconsRegular.currencyDollar,
              label: 'Amount in ${_currency!.name}',
              value: _fiat!,
            ),
          ),
      ],
    );
  }
}
