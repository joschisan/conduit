import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/widgets/drawer_shell_widget.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/detail_row_widget.dart';
import 'package:conduit/widgets/amount_rows.dart';
import 'package:conduit/widgets/async_button_widget.dart';
import 'package:conduit/widgets/warning_card_widget.dart';
import 'package:conduit/utils/auth_utils.dart';
import 'package:conduit/utils/drawer_utils.dart';

/// Confirms a Lightning payment once a gateway has been selected and its fee
/// quoted. The gateway returned by [ConduitClient.lnCalculateFees] is passed
/// to [ConduitClient.lnSend] so the fee shown here matches what is charged.
class ConfirmLightningSendDrawer extends StatelessWidget {
  final ConduitClient client;
  final Bolt11InvoiceWrapper invoice;
  final LnSendFees fees;

  const ConfirmLightningSendDrawer({
    super.key,
    required this.client,
    required this.invoice,
    required this.fees,
  });

  static Future<void> show(
    BuildContext context, {
    required ConduitClient client,
    required Bolt11InvoiceWrapper invoice,
    required LnSendFees fees,
  }) {
    return DrawerUtils.show(
      context: context,
      child: ConfirmLightningSendDrawer(
        client: client,
        invoice: invoice,
        fees: fees,
      ),
    );
  }

  Future<void> _handleConfirm(BuildContext context) async {
    await requireBiometricAuth(context);

    await client.lnSend(invoice: invoice, gateway: fees.gatewayUrl);

    if (!context.mounted) return;

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final amountSats = invoice.amountSats();

    return DrawerShell(
      icon: PhosphorIconsRegular.lightning,
      title: 'Send Lightning',
      children: [
        BorderedList.column(
          children: [
            ...amountRows(client: client, amountSats: amountSats),
            DetailRow(
              icon: PhosphorIconsRegular.network,
              label: 'Network Fee',
              value:
                  '${NumberFormat('#,###').format(fees.feeSats)} sat · ${(fees.feeSats / amountSats * 100).toStringAsFixed(1)}%',
            ),
          ],
        ),
        if (fees.feeSats > amountSats * 0.02) ...[
          const SizedBox(height: 16),
          WarningCard(
            icon: PhosphorIconsRegular.warning,
            text:
                'High Relative Fee of ${(fees.feeSats / amountSats * 100).toStringAsFixed(1)}%',
          ),
        ],
        const SizedBox(height: 16),
        AsyncButton(text: 'Confirm', onPressed: () => _handleConfirm(context)),
      ],
    );
  }
}
