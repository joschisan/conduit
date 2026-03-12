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
import 'package:conduit/widgets/onboarding_card_widget.dart';

class RecentPayments extends StatefulWidget {
  final ConduitClient client;
  final Stream<ConduitEvent> stream;
  final int maxItems;
  final void Function(ConduitPayment) onTransactionTap;

  const RecentPayments({
    super.key,
    required this.client,
    required this.stream,
    required this.maxItems,
    required this.onTransactionTap,
  });

  @override
  State<RecentPayments> createState() => _RecentPaymentsState();
}

class _RecentPaymentsState extends State<RecentPayments> {
  final _listKey = GlobalKey<AnimatedListState>();
  final List<ConduitPayment> _displayPayments =
      []; // max maxItems, for AnimatedList
  StreamSubscription<ConduitEvent>? _subscription;

  static const _notificationWindowMs = 1000;

  bool _isRecentEvent(int timestamp) {
    return timestamp >
        DateTime.now().millisecondsSinceEpoch - _notificationWindowMs;
  }

  @override
  void initState() {
    super.initState();
    _subscribeToEvents();
  }

  void _subscribeToEvents() {
    _subscription = widget.stream.listen((message) {
      if (!mounted) return;

      switch (message) {
        case ConduitEvent_Event(:final field0):
          _insertDisplayPayment(
            field0,
            animate: _isRecentEvent(field0.timestamp),
          );

          _showEventNotification(
            timestamp: field0.timestamp,
            success: field0.success,
            incoming: field0.incoming,
            amountSats: field0.amountSats,
            paymentType: field0.paymentType,
          );

        case ConduitEvent_Update(:final field0):
          _updatePayment(field0);
      }
    });
  }

  void _insertDisplayPayment(ConduitPayment payment, {required bool animate}) {
    final duration =
        animate ? const Duration(milliseconds: 600) : Duration.zero;

    setState(() {
      _displayPayments.insert(0, payment);
    });

    // AnimatedList may not exist yet (first items trigger rebuild from
    // carousel to list). insertItem/removeItem are no-ops via ?. until
    // the AnimatedList builds; initialItemCount handles those items.
    _listKey.currentState?.insertItem(0, duration: duration);

    if (_displayPayments.length > widget.maxItems) {
      final removed = _displayPayments.removeAt(widget.maxItems);
      _listKey.currentState?.removeItem(
        widget.maxItems,
        (context, animation) => _buildAnimatedItem(removed, animation),
        duration: duration,
      );
    }
  }

  void _updatePayment(ConduitUpdate update) {
    final index = _displayPayments.lastIndexWhere(
      (e) => e.operationId == update.operationId,
    );
    if (index == -1) return;

    final event = _displayPayments[index];

    setState(() {
      _displayPayments[index] = ConduitPayment(
        operationId: event.operationId,
        incoming: event.incoming,
        paymentType: event.paymentType,
        amountSats: event.amountSats,
        feeSats: event.feeSats,
        timestamp: event.timestamp,
        success: update.success,
        oob: update.oob,
      );
    });

    _showEventNotification(
      timestamp: update.timestamp,
      success: update.success,
      incoming: event.incoming,
      amountSats: event.amountSats,
      paymentType: event.paymentType,
    );
  }

  void _showEventNotification({
    required int timestamp,
    required bool? success,
    required bool incoming,
    required int amountSats,
    required PaymentType paymentType,
  }) {
    if (!_isRecentEvent(timestamp)) return;

    if (success == true) {
      if (incoming) {
        NotificationUtils.showReceive(context, amountSats, paymentType);
      } else {
        HapticFeedback.heavyImpact();
      }
    } else if (success == false) {
      HapticFeedback.heavyImpact();
      if (incoming) {
        NotificationUtils.showError(context, 'Failed to receive payment');
      } else {
        NotificationUtils.showError(context, 'Failed to send payment');
      }
    }
  }

  static List<ConduitPayment> _mergeUpdates(List<ConduitEvent> events) {
    final payments = <ConduitPayment>[];
    final indexByOperationId = <String, int>{};

    // Events arrive newest-first; iterate in reverse for chronological merge
    for (final event in events) {
      switch (event) {
        case ConduitEvent_Event(:final field0):
          indexByOperationId[field0.operationId] = payments.length;
          payments.add(field0);
        case ConduitEvent_Update(:final field0):
          final index = indexByOperationId[field0.operationId];
          if (index == null) continue;
          final original = payments[index];
          payments[index] = ConduitPayment(
            operationId: original.operationId,
            incoming: original.incoming,
            paymentType: original.paymentType,
            amountSats: original.amountSats,
            feeSats: original.feeSats,
            timestamp: original.timestamp,
            success: field0.success,
            oob: field0.oob,
          );
      }
    }

    return payments.reversed.toList();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Widget _buildAnimatedItem(
    ConduitPayment payment,
    Animation<double> animation,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubic,
    );

    return SizeTransition(
      sizeFactor: curved,
      child: FadeTransition(
        opacity: curved,
        child: PaymentCard(
          key: ValueKey(payment.operationId),
          event: payment,
          onTap: () => widget.onTransactionTap(payment),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_displayPayments.isEmpty) {
      return const Align(
        alignment: Alignment.topCenter,
        child: _OnboardingCarousel(),
      );
    }

    return Column(
      children: [
        AnimatedList(
          key: _listKey,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          initialItemCount: _displayPayments.length,
          itemBuilder: (context, index, animation) {
            final payment = _displayPayments[index];
            return BorderedList.decorateItem(
              context: context,
              child: _buildAnimatedItem(payment, animation),
              isFirst: index == 0,
              isLast: index == _displayPayments.length - 1,
            );
          },
        ),
        Center(
          child: TextButton(
            onPressed: () async {
              final events = await widget.client.getPaymentHistory();

              final payments = _mergeUpdates(events);

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

class _OnboardingCarousel extends StatefulWidget {
  const _OnboardingCarousel();

  @override
  State<_OnboardingCarousel> createState() => _OnboardingCarouselState();
}

class _OnboardingCarouselState extends State<_OnboardingCarousel> {
  static const _pages = [
    (
      icon: Icons.bolt,
      title: 'Lightning',
      description:
          'Create a lightning invoice to receive bitcoin from any other lightning wallet.'
          '\n\n'
          'If you already have a lightning wallet, this is the quickest way to top up your balance.',
    ),
    (
      icon: Icons.currency_bitcoin,
      title: 'Onchain',
      description:
          'Generate an onchain address to move onchain bitcoin directly into the federation.'
          '\n\n'
          'Whenever the time comes, you can spend your cold storage bitcoin with great privacy.',
    ),
    (
      icon: Icons.toll,
      title: 'eCash',
      description:
          'Simply enter an amount and share the ecash token with another user of the federation.'
          '\n\n'
          'This is the most private and efficient way to transact within a federation.',
    ),
  ];

  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    return OnboardingCard(
      icon: page.icon,
      title: page.title,
      description: page.description,
      actionText: 'Next',
      onAction:
          _currentPage < _pages.length - 1
              ? () => setState(() => _currentPage++)
              : null,
    );
  }
}
