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

  @override
  Widget build(BuildContext context) {
    if (_events.isEmpty) {
      return const Align(
        alignment: Alignment.topCenter,
        child: _OnboardingCarousel(),
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

class _OnboardingCarousel extends StatefulWidget {
  const _OnboardingCarousel();

  @override
  State<_OnboardingCarousel> createState() => _OnboardingCarouselState();
}

class _OnboardingCarouselState extends State<_OnboardingCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    (
      icon: Icons.bolt,
      title: 'Lightning',
      description:
          'Create a lightning invoice to receive bitcoin from any other lightning wallet.'
          '\n\n'
          'If you already have a lightning wallet this is the quickest way to top up your balance.',
    ),
    (
      icon: Icons.currency_bitcoin,
      title: 'Onchain',
      description:
          'Generate a onchain address to move onchain bitcoin directly into the federation.'
          '\n\n'
          'Whenever the time comes you can spend your cold storage bitcoin with great privacy.',
    ),
    (
      icon: Icons.toll,
      title: 'eCash',
      description:
          'Use ecash to send bitcoin to another user of this federation - simply enter the amount and share the eCash token with the recipient.'
          '\n\n'
          'This is the most private and fee efficient way to transact within a federation.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 220,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              page.icon,
                              size: 48,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(page.title, style: theme.textTheme.titleLarge),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (index) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        index == _currentPage
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
