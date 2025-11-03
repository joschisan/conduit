import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:conduit/bridge_generated.dart/events.dart';
import 'package:conduit/widgets/drawer_shell.dart';
import 'package:conduit/widgets/amount_card.dart';
import 'package:conduit/utils/payment_type_utils.dart';
import 'package:conduit/utils/drawer_utils.dart';
import 'package:conduit/utils/notification_utils.dart';

class EventDetailsDrawer extends StatelessWidget {
  final ConduitPayment event;

  const EventDetailsDrawer({super.key, required this.event});

  static Future<void> show(
    BuildContext context, {
    required ConduitPayment event,
  }) {
    return DrawerUtils.show(
      context: context,
      child: EventDetailsDrawer(event: event),
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
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: event.oob!));
                  NotificationUtils.showCopy(context, event.oob!);
                },
              )
              : null,
      children: [
        AmountCard(amountSats: event.amountSats, feeSats: event.feeSats),
      ],
    );
  }
}
