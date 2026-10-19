import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/widgets/amount_entry_widget.dart';
import 'package:conduit/screens/display_invoice_screen.dart';

class InvoiceAmountScreen extends StatelessWidget {
  final ConduitClient client;
  final bool fiat;

  const InvoiceAmountScreen({
    super.key,
    required this.client,
    this.fiat = false,
  });

  Future<void> _handleConfirm(BuildContext context, int amountSats) async {
    final receive = await client.lnReceive(amountSat: amountSats);

    if (!context.mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder:
            (_) => DisplayInvoiceScreen(
              client: client,
              invoice: receive.invoice,
              amount: amountSats,
              feeSats: receive.feeSats,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receive Lightning')),
      body: SafeArea(
        child: AmountEntryWidget(
          client: client,
          fiat: fiat,
          onConfirm: (amountSats) => _handleConfirm(context, amountSats),
        ),
      ),
    );
  }
}
