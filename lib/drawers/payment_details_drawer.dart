import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/events.dart';
import 'package:conduit/widgets/drawer_shell_widget.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/payment_summary_row_widget.dart';
import 'package:conduit/widgets/detail_row_widget.dart';
import 'package:conduit/widgets/shareable_row_widget.dart';
import 'package:conduit/utils/payment_utils.dart';
import 'package:conduit/utils/drawer_utils.dart';
import 'package:conduit/utils/currency_utils.dart';

class PaymentDetailsDrawer extends StatefulWidget {
  final ConduitPayment event;
  final ConduitClient client;

  const PaymentDetailsDrawer({
    super.key,
    required this.event,
    required this.client,
  });

  static Future<void> show(
    BuildContext context, {
    required ConduitPayment event,
    required ConduitClient client,
  }) {
    return DrawerUtils.show(
      context: context,
      child: PaymentDetailsDrawer(event: event, client: client),
    );
  }

  @override
  State<PaymentDetailsDrawer> createState() => _PaymentDetailsDrawerState();
}

class _PaymentDetailsDrawerState extends State<PaymentDetailsDrawer> {
  int? _federationFeeMsats;

  @override
  void initState() {
    super.initState();
    _loadFederationFee();
  }

  Future<void> _loadFederationFee() async {
    final fee = await widget.client.operationFeeMsats(
      operationId: widget.event.operationId,
    );

    if (!mounted) return;

    setState(() => _federationFeeMsats = fee);
  }

  String _formatDateTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('d MMMM y | HH:mm').format(dateTime);
  }

  String _sats(int amount) => '${NumberFormat('#,###').format(amount)} sat';

  String _msatsAsSats(int msats) =>
      '${NumberFormat('#,##0.#').format(msats / 1000)} sat';

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
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
                  '${PaymentTypeUtils.getStatus(incoming: event.incoming, success: event.success)} · ${formatRelativeTime(DateTime.fromMillisecondsSinceEpoch(event.timestamp))}',
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
                    '${_sats(fee)} · ${NumberFormat('#,##0.#').format(fee / event.amountSats * 100)}%',
              ),
            if (_federationFeeMsats case final federationFee?)
              DetailRow(
                icon: PhosphorIconsRegular.wallet,
                label: 'Mint Fee',
                value: _msatsAsSats(federationFee),
              ),
            if (event.address != null)
              ShareableRow(data: event.address!, label: 'Bitcoin Address'),
            if (event.txid != null)
              ShareableRow(data: event.txid!, label: 'Transaction ID'),
            if (event.preimage != null)
              ShareableRow(data: event.preimage!, label: 'Preimage'),
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
