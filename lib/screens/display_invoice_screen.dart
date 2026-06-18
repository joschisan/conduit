import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/widgets/qr_code_widget.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/shareable_row_widget.dart';
import 'package:conduit/widgets/detail_row_widget.dart';
import 'package:conduit/widgets/amount_rows.dart';

class DisplayInvoiceScreen extends StatelessWidget {
  final ConduitClient client;
  final String invoice;
  final int amount;
  final int feeSats;

  const DisplayInvoiceScreen({
    super.key,
    required this.client,
    required this.invoice,
    required this.amount,
    required this.feeSats,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Receive Lightning')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          QrCodeWidget(data: invoice),
          const SizedBox(height: 16),
          BorderedList.column(
            children: [
              ShareableRow(data: invoice, label: 'Lightning Invoice'),
              ...amountRows(client: client, amountSats: amount),
              DetailRow(
                icon: PhosphorIconsRegular.network,
                label: 'Network Fee',
                value: '${NumberFormat('#,###').format(feeSats)} sat',
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
