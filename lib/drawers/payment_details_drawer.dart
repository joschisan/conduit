import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:conduit/bridge_generated.dart/events.dart';
import 'package:conduit/widgets/drawer_shell_widget.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/detail_row_widget.dart';
import 'package:conduit/widgets/shareable_row_widget.dart';
import 'package:conduit/utils/payment_utils.dart';
import 'package:conduit/utils/drawer_utils.dart';

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

  String _title() {
    final type = switch (event.paymentType) {
      PaymentType.lightning => 'Lightning',
      PaymentType.bitcoin => 'Onchain',
      PaymentType.ecash => 'eCash',
    };

    return '$type ${event.incoming ? 'Receive' : 'Send'}';
  }

  String _formatDateTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('EEEE d MMMM, HH:mm').format(dateTime);
  }

  String _sats(int amount) => '${NumberFormat('#,###').format(amount)} sat';

  @override
  Widget build(BuildContext context) {
    final fee = event.feeSats;
    final sign = event.incoming ? '+' : '-';

    return DrawerShell(
      icon: PaymentTypeUtils.getIcon(event.paymentType),
      title: _title(),
      children: [
        BorderedList.column(
          children: [
            DetailRow(
              icon:
                  event.incoming
                      ? PhosphorIconsRegular.arrowDown
                      : PhosphorIconsRegular.arrowUp,
              label:
                  event.paymentType == PaymentType.ecash
                      ? 'Balance Change'
                      : 'Balance Change (incl. network fee)',
              value: '$sign ${_sats(event.amountSats)}',
            ),
            if (fee != null)
              DetailRow(
                icon: PhosphorIconsRegular.network,
                label: 'Network Fee',
                value: _sats(fee),
              ),
            if (event.address != null)
              ShareableRow(data: event.address!, label: 'Bitcoin Address'),
            if (event.txid != null)
              ShareableRow(data: event.txid!, label: 'Bitcoin Txid'),
            if (event.ecash != null)
              ShareableRow(data: event.ecash!, label: 'eCash'),
            DetailRow(
              icon: PhosphorIconsRegular.calendarBlank,
              label: 'Date',
              value: _formatDateTime(event.timestamp),
            ),
          ],
        ),
      ],
    );
  }
}
