import 'package:flutter/material.dart';
import 'package:conduit/widgets/qr_code_widget.dart';
import 'package:conduit/widgets/amount_display.dart';
import 'package:conduit/widgets/icon_badge.dart';

// Pure UI composition
Widget _buildInvoiceContent(BuildContext context, String invoice, int amount) =>
    Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Center(child: IconBadge(icon: Icons.bolt, iconSize: 48)),
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
