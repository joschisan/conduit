import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/events.dart';
import 'package:conduit/widgets/animated_entry_widget.dart';
import 'package:conduit/widgets/payment_card_widget.dart';
import 'package:conduit/widgets/section_header_widget.dart';
import 'package:conduit/widgets/amount_visibility.dart';
import 'package:conduit/screens/payment_history_screen.dart';

/// The last few payments of one account, read from a value its owner keeps
/// up to date rather than from the event stream itself, which is
/// single-subscription and listened to once per account above this widget.
class RecentPayments extends StatefulWidget {
  final ConduitClient client;
  final ValueListenable<List<ConduitPayment>> payments;
  final void Function(ConduitPayment) onTransactionTap;

  const RecentPayments({
    super.key,
    required this.client,
    required this.payments,
    required this.onTransactionTap,
  });

  @override
  State<RecentPayments> createState() => _RecentPaymentsState();
}

class _RecentPaymentsState extends State<RecentPayments> {
  /// Payments in the first snapshot render without the entry animation; only
  /// payments appearing after the widget mounted grow in.
  late final Set<String> _initialIds = {
    for (final p in widget.payments.value) p.operationId,
  };

  Future<void> _openHistory() async {
    // Read the home screen's current unit before awaiting so history opens in
    // the same sats/fiat mode the user was viewing.
    final fiat = AmountDisplay.of(context) == BalanceDisplay.fiat;
    final payments = await widget.client.getPaymentHistory();

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => PaymentHistoryScreen(
              client: widget.client,
              payments: payments,
              fiat: fiat,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<ConduitPayment>>(
      valueListenable: widget.payments,
      builder: (context, payments, _) {
        if (payments.isEmpty) {
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
            for (final payment in payments)
              KeyedSubtree(
                key: ValueKey(payment.operationId),
                child: AnimatedEntry(
                  animate: !_initialIds.contains(payment.operationId),
                  child: PaymentCard(
                    event: payment,
                    onTap: () => widget.onTransactionTap(payment),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
