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
      return const Align(
        alignment: Alignment.topCenter,
        child: _OnboardingCarousel(),
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
