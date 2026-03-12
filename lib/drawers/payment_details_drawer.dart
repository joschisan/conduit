import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:conduit/bridge_generated.dart/events.dart';
import 'package:conduit/widgets/drawer_shell_widget.dart';
import 'package:conduit/widgets/amount_card_widget.dart';
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

  String _formatDateTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('MMM dd, HH:mm:ss').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return DrawerShell(
      icon: PaymentTypeUtils.getIcon(event.paymentType),
      title: _formatDateTime(event.timestamp),
      topRightButton:
          event.oob != null
              ? IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  SharePlus.instance.share(ShareParams(text: event.oob!));
                },
              )
              : null,
      children: [
        AmountCard(amountSats: event.amountSats, feeSats: event.feeSats),
      ],
    );
  }
}
