import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/events.dart';
import 'package:conduit/widgets/animated_entry_widget.dart';
import 'package:conduit/widgets/payment_card_widget.dart';
import 'package:conduit/widgets/section_header_widget.dart';
import 'package:conduit/utils/notification_utils.dart';
import 'package:conduit/screens/payment_history_screen.dart';

class RecentPayments extends StatefulWidget {
  final ConduitClient client;
  final Stream<RecentPaymentsUpdate> stream;
  final void Function(ConduitPayment) onTransactionTap;

  const RecentPayments({
    super.key,
    required this.client,
    required this.stream,
    required this.onTransactionTap,
  });

  @override
  State<RecentPayments> createState() => _RecentPaymentsState();
}

class _RecentPaymentsState extends State<RecentPayments> {
  List<ConduitPayment> _payments = [];
  StreamSubscription<RecentPaymentsUpdate>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.stream.listen(_onSnapshot);
  }

  void _onSnapshot(RecentPaymentsUpdate update) {
    if (!mounted) return;
    setState(() => _payments = update.payments);
    if (update.notification case final notification?) {
      _showNotification(notification);
    }
  }

  void _showNotification(PaymentNotification notification) {
    HapticFeedback.heavyImpact();

    if (!notification.success) {
      if (notification.incoming) {
        NotificationUtils.showError(context, 'Failed to receive payment');
      } else {
        NotificationUtils.showError(context, 'Failed to send payment');
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _openHistory() async {
    final payments = await widget.client.getPaymentHistory();

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentHistoryScreen(payments: payments),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_payments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SectionHeader(
            title: 'Recent Payments',
            action: 'History',
            onAction: _openHistory,
          ),
        ),
        for (var i = 0; i < _payments.length; i++)
          KeyedSubtree(
            key: ValueKey(_payments[i].operationId),
            child: AnimatedEntry(
              child: PaymentCard(
                event: _payments[i],
                onTap: () => widget.onTransactionTap(_payments[i]),
              ),
            ),
          ),
      ],
    );
  }
}
