import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/widgets/amount_entry_widget.dart';
import 'package:conduit/widgets/async_text_button.dart';
import 'package:conduit/screens/display_invoice_screen.dart';
import 'package:conduit/screens/display_lnurl_screen.dart';

class LightningReceiveAmountScreen extends StatelessWidget {
  final ConduitClient client;

  const LightningReceiveAmountScreen({super.key, required this.client});

  Future<void> _handleLnurlTap(BuildContext context) async {
    final lnurl = await client.lnurl();

    if (!context.mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => DisplayLnurlScreen(lnurl: lnurl)),
    );
  }

  Future<void> _handleConfirm(BuildContext context, int amountSats) async {
    final invoice = await client.lnReceive(amountSat: amountSats);

    if (!context.mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder:
            (_) => DisplayInvoiceScreen(invoice: invoice, amount: amountSats),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lightning'),
        actions: [
          AsyncTextButton(
            text: 'LNURL',
            onPressed: () => _handleLnurlTap(context),
          ),
        ],
      ),
      body: SafeArea(
        child: AmountEntryWidget(
          client: client,
          onConfirm: (amountSats) => _handleConfirm(context, amountSats),
        ),
      ),
    );
  }
}
