import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/events.dart';
import 'package:conduit/widgets/drawer_shell_widget.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/payment_summary_row_widget.dart';
import 'package:conduit/widgets/amount_rows.dart';
import 'package:conduit/widgets/async_button_widget.dart';
import 'package:conduit/drawers/confirm_lightning_send_drawer.dart';
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
  /// Selects the gateway and quotes its fee, then hands off to the confirmation
  /// drawer. The gateway is only chosen here, once the user opts to continue.
  Future<void> _handleContinue() async {
    final fees = await widget.client.lnCalculateFees(invoice: widget.invoice);

    if (!mounted) return;

    Navigator.of(context).pop();
    ConfirmLightningSendDrawer.show(
      context,
      client: widget.client,
      invoice: widget.invoice,
      fees: fees,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DrawerShell(
      children: [
        BorderedList.column(
          children: [
            const PaymentSummaryRow(
              paymentType: PaymentType.lightning,
              incoming: false,
              status: 'Send',
            ),
            ...amountRows(
              client: widget.client,
              amountSats: widget.invoice.amountSats(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AsyncButton(text: 'Continue', onPressed: _handleContinue),
      ],
    );
  }
}
