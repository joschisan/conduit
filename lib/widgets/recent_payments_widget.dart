import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/events.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/payment_card_widget.dart';
import 'package:conduit/utils/notification_utils.dart';
import 'package:conduit/utils/styles.dart';
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
    if (notification.success) {
      if (notification.incoming) {
        NotificationUtils.showReceive(
          context,
          notification.amountSats,
          notification.paymentType,
        );
      } else {
        HapticFeedback.heavyImpact();
      }
    } else {
      HapticFeedback.heavyImpact();
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

  @override
  Widget build(BuildContext context) {
    if (_payments.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 64),
          Text(
            'You have no payments yet.',
            textAlign: TextAlign.center,
            style: smallStyle.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        for (var i = 0; i < _payments.length; i++)
          KeyedSubtree(
            key: ValueKey(_payments[i].operationId),
            child: BorderedList.decorateItem(
              context: context,
              child: _AnimatedEntry(
                child: PaymentCard(
                  event: _payments[i],
                  onTap: () => widget.onTransactionTap(_payments[i]),
                ),
              ),
              isFirst: i == 0,
              isLast: i == _payments.length - 1,
            ),
          ),
        Center(
          child: TextButton(
            onPressed: () async {
              final payments = await widget.client.getPaymentHistory();

              if (!context.mounted) return;

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PaymentHistoryScreen(payments: payments),
                ),
              );
            },
            child: Text(
              'Payment History',
              style: mediumStyle.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnimatedEntry extends StatefulWidget {
  final Widget child;
  const _AnimatedEntry({required this.child});

  @override
  State<_AnimatedEntry> createState() => _AnimatedEntryState();
}

class _AnimatedEntryState extends State<_AnimatedEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 500),
    vsync: this,
  )..forward();

  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(sizeFactor: _animation, child: widget.child);
  }
}
