import 'dart:async';

import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/events.dart';
import 'package:conduit/widgets/event_transaction_item.dart';
import 'package:conduit/utils/notification_utils.dart';

class EventTransactionsList extends StatefulWidget {
  final Stream<ConduitEvent> stream;
  final void Function(ConduitPayment) onTransactionTap;

  const EventTransactionsList({
    super.key,
    required this.stream,
    required this.onTransactionTap,
  });

  @override
  State<EventTransactionsList> createState() => _EventTransactionsListState();
}

class _EventTransactionsListState extends State<EventTransactionsList> {
  final List<ConduitPayment> _events = [];
  final Set<String> _animatingIds = {};
  StreamSubscription<ConduitEvent>? _subscription;

  // Only notify for events in the last second (prevents old events from showing notifications on load)
  static const _notificationWindowMs = 1000;

  bool _isRecentEvent(int timestamp) {
    return timestamp >
        DateTime.now().millisecondsSinceEpoch - _notificationWindowMs;
  }

  void _markForAnimation(String operationId) {
    _animatingIds.add(operationId);
    // Remove from set after animation duration
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _animatingIds.remove(operationId);
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _subscribeToEvents();
  }

  void _showEventNotification({
    required int timestamp,
    required bool? success,
    required bool incoming,
    required int amountSats,
    required PaymentType paymentType,
  }) {
    // Only show notifications for recent events
    if (!_isRecentEvent(timestamp)) {
      return;
    }

    if (success == true) {
      if (incoming) {
        NotificationUtils.showReceive(context, amountSats, paymentType);
      } else {
        NotificationUtils.showSend(context, amountSats, paymentType);
      }
    } else if (success == false) {
      if (incoming) {
        NotificationUtils.showError(context, 'Failed to receive payment.');
      } else {
        NotificationUtils.showError(context, 'Failed to send payment.');
      }
    }
  }

  void _subscribeToEvents() {
    _subscription = widget.stream.listen((message) {
      if (!mounted) return;

      switch (message) {
        case ConduitEvent_Event(:final field0):
          // New event - append to end (O(1) constant time)
          // Display reversed so newest appears at top
          setState(() {
            _events.add(field0);
          });

          // Only animate recent events (not initial load)
          if (_isRecentEvent(field0.timestamp)) {
            _markForAnimation(field0.operationId);
          }

          _showEventNotification(
            timestamp: field0.timestamp,
            success: field0.success,
            incoming: field0.incoming,
            amountSats: field0.amountSats,
            paymentType: field0.paymentType,
          );

        case ConduitEvent_Update(:final field0):
          // Update existing event - search from end for better performance
          final index = _events.lastIndexWhere(
            (e) => e.operationId == field0.operationId,
          );

          if (index == -1) return;

          final event = _events[index];

          setState(() {
            _events[index] = ConduitPayment(
              operationId: event.operationId,
              incoming: event.incoming,
              paymentType: event.paymentType,
              amountSats: event.amountSats,
              feeSats: event.feeSats,
              timestamp: event.timestamp,
              success: field0.success,
              oob: field0.oob,
            );
          });

          _showEventNotification(
            timestamp: field0.timestamp,
            success: field0.success,
            incoming: event.incoming,
            amountSats: event.amountSats,
            paymentType: event.paymentType,
          );
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Widget _buildOnboardingCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 8.0,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Tap the lightning button to create an invoice and receive your first payment.',
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_events.isEmpty) {
      return Align(
        alignment: Alignment.topCenter,
        child: _buildOnboardingCard(context),
      );
    }

    return ListView.builder(
      itemCount: _events.length,
      itemBuilder: (context, index) {
        // Access items in reverse order (newest at end of list, show at top)
        final event = _events[_events.length - 1 - index];
        return EventTransactionItem(
          key: ValueKey(event.operationId),
          event: event,
          animate: _animatingIds.contains(event.operationId),
          onTap: () => widget.onTransactionTap(event),
        );
      },
    );
  }
}
