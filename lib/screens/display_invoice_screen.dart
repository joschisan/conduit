import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/widgets/qr_code_widget.dart';
import 'package:conduit/widgets/qr_display_layout_widget.dart';
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
    appBar: AppBar(title: const Text('Lightning Invoice')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: QrDisplayLayout(
          header: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bolt,
                size: heroIconSize,
                color: Theme.of(context).colorScheme.primary,
              ),
              AmountDisplay(amount),
            ],
          ),
          qrCode: QrCodeWidget(data: invoice),
          description:
              'This invoice can only be paid once. To receive recurring payments, please use your lightning url.',
        ),
      ),
    ),
  );
}
