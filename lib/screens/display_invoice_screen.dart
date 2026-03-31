import 'package:flutter/material.dart';
import 'package:conduit/widgets/qr_code_widget.dart';
import 'package:conduit/widgets/shareable_data_widget.dart';
import 'package:conduit/widgets/amount_display_widget.dart';

class DisplayInvoiceScreen extends StatelessWidget {
  final String invoice;
  final int amount;

  const DisplayInvoiceScreen({
    super.key,
    required this.invoice,
    required this.amount,
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
            ShareableData(data: invoice),
            Expanded(child: Center(child: AmountDisplay(amount))),
          ],
        ),
      ),
    ),
  );
}
