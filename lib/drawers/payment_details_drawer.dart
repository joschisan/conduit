import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:conduit/bridge_generated.dart/events.dart';
import 'package:conduit/widgets/drawer_shell_widget.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/payment_summary_row_widget.dart';
import 'package:conduit/widgets/detail_row_widget.dart';
import 'package:conduit/widgets/shareable_row_widget.dart';
import 'package:conduit/utils/payment_utils.dart';
import 'package:conduit/utils/drawer_utils.dart';
import 'package:conduit/utils/currency_utils.dart';

class PaymentDetailsDrawer extends StatelessWidget {
  final ConduitPayment event;

  const PaymentDetailsDrawer({super.key, required this.event});

  static Future<void> show(
    BuildContext context, {
    required ConduitPayment event,
  }) {
    return DrawerUtils.show(
      context: context,
      child: PaymentDetailsDrawer(event: event),
    );
  }

  String _formatDateTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('EEEE d MMMM, HH:mm').format(dateTime);
  }

  String _sats(int amount) => '${NumberFormat('#,###').format(amount)} sat';

  @override
  Widget build(BuildContext context) {
    final fee = event.feeSats;
    final fiat = historicalFiat(event);

    return DrawerShell(
      children: [
        BorderedList.column(
          children: [
            PaymentSummaryRow(
              paymentType: event.paymentType,
              incoming: event.incoming,
              status:
                  '${PaymentTypeUtils.getStatus(incoming: event.incoming, success: event.success)} · ${_formatDateTime(event.timestamp)}',
              iconColor: event.success == false ? Colors.amber : null,
            ),
            DetailRow(
              icon: PhosphorIconsRegular.currencyBtc,
              label: 'Bitcoin',
              value: _sats(event.amountSats),
            ),
            if (fiat != null)
              DetailRow(
                icon: PhosphorIconsRegular.currencyDollar,
                label: fiat.currency,
                value: fiat.amount,
              ),
            if (fee != null)
              DetailRow(
                icon: PhosphorIconsRegular.network,
                label: 'Network Fee',
                value:
                    '${_sats(fee)} · ${(fee / event.amountSats * 100).toStringAsFixed(1)}%',
              ),
            if (event.address != null)
              ShareableRow(data: event.address!, label: 'Bitcoin Address'),
            if (event.txid != null)
              ShareableRow(data: event.txid!, label: 'Bitcoin Txid'),
            if (event.preimage != null)
              ShareableRow(data: event.preimage!, label: 'Preimage'),
            if (event.ecash != null)
              ShareableRow(data: event.ecash!, label: 'eCash'),
          ],
        ),
      ],
    );
  }
}
