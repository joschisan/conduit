import 'package:flutter/material.dart';
import 'package:conduit/widgets/qr_code_widget.dart';
import 'package:conduit/widgets/amount_display.dart';

// Pure UI composition
Widget _buildInvoiceContent(BuildContext context, String invoice, int amount) =>
    Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Center(
            child: Icon(
              Icons.bolt,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        QrCodeWidget(data: invoice),
        Expanded(child: Center(child: AmountDisplay(amount))),
      ],
    );

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
    appBar: AppBar(),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox.expand(
          child: _buildInvoiceContent(context, invoice, amount),
        ),
      ),
    ),
  );
}
