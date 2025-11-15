import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/widgets/event_transaction_item.dart';
import 'package:conduit/utils/notification_utils.dart';

class EventTransactionsList extends StatefulWidget {
  final Stream<ConduitEvent> stream;
  final void Function(ConduitPayment)? onTransactionTap;

  const EventTransactionsList({
    super.key,
    required this.stream,
    this.onTransactionTap,
  });

  @override
  State<EventTransactionsList> createState() => _EventTransactionsListState();
}

class _EventTransactionsListState extends State<EventTransactionsList> {
  final List<ConduitPayment> _events = [];

  @override
  void initState() {
    super.initState();
    _subscribeToEvents();
  }

  void _subscribeToEvents() {
    widget.stream.listen((message) {
      if (!mounted) return;

      switch (message) {
        case ConduitEvent_Event(:final field0):
          // New event - append to end (O(1) constant time)
          // Display reversed so newest appears at top
          setState(() {
            _events.add(field0);
          });

          // If event is younger then 1 second, show a notification
          if (field0.timestamp > DateTime.now().millisecondsSinceEpoch - 1000) {
            if (field0.success != null && field0.success == true) {
              if (field0.incoming) {
                NotificationUtils.showReceive(context, field0.amountSats);
              } else {
                NotificationUtils.showSend(context, field0.amountSats);
              }
            }
          }

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

          // If event is younger then 1 second, show a notification
          if (field0.timestamp > DateTime.now().millisecondsSinceEpoch - 1000) {
            if (field0.success == true) {
              if (event.incoming) {
                NotificationUtils.showReceive(context, event.amountSats);
              } else {
                NotificationUtils.showSend(context, event.amountSats);
              }
            } else {
              if (event.incoming) {
                NotificationUtils.showError(
                  context,
                  'Failed to receive payment.',
                );
              } else {
                NotificationUtils.showError(context, 'Failed to send payment.');
              }
            }
          }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_events.isEmpty) {
      return Center(
        child: Text(
          'No transactions yet',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _events.length,
      itemBuilder: (context, index) {
        // Access items in reverse order (newest at end of list, show at top)
        final event = _events[_events.length - 1 - index];
        return EventTransactionItem(
          event: event,
          onTap:
              widget.onTransactionTap != null
                  ? () => widget.onTransactionTap!(event)
                  : null,
        );
      },
    );
  }
}
