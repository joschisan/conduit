import 'package:flutter/material.dart';
import 'package:conduit/widgets/qr_code_widget.dart';
import 'package:conduit/widgets/copy_button.dart';
import 'package:conduit/widgets/amount_display.dart';

// Pure UI composition
Widget _buildInvoiceContent(BuildContext context, String invoice, int amount) =>
    Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AmountDisplay(amount),
        const SizedBox(height: 16),
        QrCodeWidget(data: invoice),
        const SizedBox(height: 16),
        CopyButton(data: invoice, message: 'Invoice copied to clipboard'),
      ],
    );

class DisplayInvoiceScreen extends StatelessWidget {
  final String invoice;
  final int amount;

  const DisplayInvoiceScreen._({
    super.key,
    required this.invoice,
    required this.amount,
  });

  // Factory constructor for backward compatibility
  factory DisplayInvoiceScreen({
    Key? key,
    required String invoice,
    required int amount,
    required String description,
  }) => DisplayInvoiceScreen._(key: key, invoice: invoice, amount: amount);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lightning Invoice')),
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
