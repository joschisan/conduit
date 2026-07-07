import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/events.dart';
import 'package:conduit/widgets/drawer_shell_widget.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/payment_summary_row_widget.dart';
import 'package:conduit/widgets/detail_row_widget.dart';
import 'package:conduit/widgets/amount_rows.dart';
import 'package:conduit/widgets/async_button_widget.dart';
import 'package:conduit/utils/auth_utils.dart';
import 'package:conduit/utils/drawer_utils.dart';
import 'package:conduit/utils/notification_utils.dart';

/// Confirms a Lightning payment. The gateway is selected and its fee quoted
/// as soon as the drawer opens; the fee row shows a spinner until the quote
/// arrives and the confirm button stays disabled without one. A failed quote
/// pops the drawer and surfaces an error notification. The quoted gateway is
/// passed to [ConduitClient.lnSend] so the fee shown here matches what is
/// charged.
class LightningSendDrawer extends StatefulWidget {
  final ConduitClient client;
  final Bolt11InvoiceWrapper invoice;

  const LightningSendDrawer({
    super.key,
    required this.client,
    required this.invoice,
  });

  static Future<void> show(
    BuildContext context, {
    required ConduitClient client,
    required Bolt11InvoiceWrapper invoice,
  }) {
    return DrawerUtils.show(
      context: context,
      child: LightningSendDrawer(client: client, invoice: invoice),
    );
  }

  @override
  State<LightningSendDrawer> createState() => _LightningSendDrawerState();
}

class _LightningSendDrawerState extends State<LightningSendDrawer> {
  LnSendFees? _fees;

  @override
  void initState() {
    super.initState();
    _loadFees();
  }

  Future<void> _loadFees() async {
    try {
      final fees = await widget.client.lnCalculateFees(invoice: widget.invoice);

      if (!mounted) return;

      setState(() => _fees = fees);
    } catch (error) {
      if (!mounted) return;

      Navigator.of(context).pop();
      NotificationUtils.showError(context, error.toString());
    }
  }

  Future<void> _handleConfirm(LnSendFees fees) async {
    await requireBiometricAuth(context);

    await widget.client.lnSend(
      invoice: widget.invoice,
      gateway: fees.gatewayUrl,
    );

    if (!mounted) return;

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final amountSats = widget.invoice.amountSats();
    final fees = _fees;

    return DrawerShell(
      children: [
        BorderedList.column(
          children: [
            const PaymentSummaryRow(
              paymentType: PaymentType.lightning,
              incoming: false,
              status: 'Send',
            ),
            ...amountRows(client: widget.client, amountSats: amountSats),
            DetailRow(
              icon: PhosphorIconsRegular.network,
              label: 'Network Fee',
              value:
                  fees == null
                      ? null
                      : '${NumberFormat('#,###').format(fees.feeSats)} sat · ${NumberFormat('#,##0.#').format(fees.feeSats / amountSats * 100)}%',
            ),
          ],
        ),
        const SizedBox(height: 16),
        AsyncButton(
          text: 'Confirm',
          enabled: fees != null,
          onPressed: () => _handleConfirm(fees!),
        ),
      ],
    );
  }
}
