import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/widgets/drawer_shell_widget.dart';
import 'package:conduit/widgets/amount_card_widget.dart';
import 'package:conduit/widgets/async_button_widget.dart';
import 'package:conduit/utils/auth_utils.dart';
import 'package:conduit/utils/drawer_utils.dart';

class LightningInvoiceDrawer extends StatefulWidget {
  final ConduitClient client;
  final Bolt11InvoiceWrapper invoice;

  const LightningInvoiceDrawer({
    super.key,
    required this.client,
    required this.invoice,
  });

  static Future<bool?> show(
    BuildContext context, {
    required ConduitClient client,
    required Bolt11InvoiceWrapper invoice,
  }) {
    return DrawerUtils.show<bool>(
      context: context,
      child: LightningInvoiceDrawer(client: client, invoice: invoice),
    );
  }

  @override
  State<LightningInvoiceDrawer> createState() => _LightningInvoiceDrawerState();
}

class _LightningInvoiceDrawerState extends State<LightningInvoiceDrawer> {
  Future<void> _handleConfirm() async {
    await requireBiometricAuth(context);

    await widget.client.lnSend(invoice: widget.invoice);

    if (!mounted) return;

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DrawerShell(
      icon: Icons.bolt,
      title: 'Lightning Invoice',
      children: [
        AmountCard(amountSats: widget.invoice.amountSats()),
        const SizedBox(height: 16),
        AsyncButton(text: 'Confirm', onPressed: _handleConfirm),
      ],
    );
  }
}
