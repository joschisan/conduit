import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/widgets/amount_entry_widget.dart';
import 'package:conduit/widgets/async_icon_button_widget.dart';
import 'package:conduit/screens/display_invoice_screen.dart';
import 'package:conduit/screens/display_lnurl_screen.dart';

class InvoiceAmountScreen extends StatelessWidget {
  final ConduitClient client;

  const InvoiceAmountScreen({super.key, required this.client});

  Future<void> _handleLnurlTap(BuildContext context) async {
    final lnurl = await client.lnurl();
    final currencyCode = client.currencyCode();

    if (!context.mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder:
            (_) =>
                DisplayLnurlScreen(lnurl: lnurl, currencyCode: currencyCode),
      ),
    );
  }

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
      appBar: AppBar(
        title: const Text('Receive Lightning'),
        actions: [
          AsyncIconButton(
            icon: PhosphorIconsRegular.lightning,
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
