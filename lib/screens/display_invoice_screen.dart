import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:conduit/widgets/qr_code_widget.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/shareable_row_widget.dart';
import 'package:conduit/widgets/detail_row_widget.dart';

class DisplayInvoiceScreen extends StatelessWidget {
  final String invoice;
  final int amount;
  final ({String name, String amount})? fiatAmount;

  const DisplayInvoiceScreen({
    super.key,
    required this.invoice,
    required this.amount,
    this.fiatAmount,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Receive Lightning')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            QrCodeWidget(data: invoice),
            const SizedBox(height: 16),
            BorderedList.column(
              children: [
                ShareableRow(data: invoice, label: 'Lightning Invoice'),
                DetailRow(
                  icon: PhosphorIconsRegular.currencyBtc,
                  label: 'Amount in Bitcoin',
                  value: '${NumberFormat('#,###').format(amount)} sat',
                ),
                if (fiatAmount != null)
                  DetailRow(
                    icon: PhosphorIconsRegular.currencyDollar,
                    label: 'Amount in ${fiatAmount!.name}',
                    value: fiatAmount!.amount,
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
