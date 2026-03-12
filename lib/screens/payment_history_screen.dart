import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:conduit/bridge_generated.dart/events.dart';
import 'package:conduit/widgets/grouped_list_widget.dart';
import 'package:conduit/widgets/payment_card_widget.dart';
import 'package:conduit/drawers/payment_details_drawer.dart';

class PaymentHistoryScreen extends StatelessWidget {
  final List<ConduitPayment> payments;

  const PaymentHistoryScreen({super.key, required this.payments});

  static String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);
    final difference = today.difference(dateDay).inDays;

    return switch (difference) {
      0 => 'Today',
      1 => 'Yesterday',
      _ => DateFormat('EEEE d MMMM').format(date),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment History')),
      body: GroupedList<ConduitPayment>(
        items: payments,
        groupKey:
            (payment) => _formatDateHeader(
              DateTime.fromMillisecondsSinceEpoch(payment.timestamp),
            ),
        itemBuilder:
            (context, payment) => PaymentCard(
              key: ValueKey(payment.operationId),
              event: payment,
              onTap: () => PaymentDetailsDrawer.show(context, event: payment),
            ),
      ),
    );
  }
}
