import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:conduit/bridge_generated.dart/events.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/widgets/grouped_list_widget.dart';
import 'package:conduit/widgets/payment_card_widget.dart';
import 'package:conduit/drawers/payment_details_drawer.dart';

class PaymentHistoryScreen extends StatefulWidget {
  final List<ConduitPayment> payments;

  const PaymentHistoryScreen({super.key, required this.payments});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  bool _lightning = false;
  bool _bitcoin = false;
  bool _ecash = false;
  bool _incoming = false;
  bool _outgoing = false;

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

  bool get _anyType => _lightning || _bitcoin || _ecash;
  bool get _anyDirection => _incoming || _outgoing;

  List<ConduitPayment> get _filteredPayments {
    return widget.payments.where((p) {
      if (_anyType) {
        final matchesType = switch (p.paymentType) {
          PaymentType.lightning => _lightning,
          PaymentType.bitcoin => _bitcoin,
          PaymentType.ecash => _ecash,
        };
        if (!matchesType) return false;
      }
      if (_anyDirection) {
        if (p.incoming ? !_incoming : !_outgoing) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment History')),
      body: GroupedList<ConduitPayment>(
        items: _filteredPayments,
        groupKey:
            (payment) => _formatDateHeader(
              DateTime.fromMillisecondsSinceEpoch(payment.timestamp),
            ),
        header: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _FilterButton(
                icon: PhosphorIconsRegular.lightning,
                active: _lightning,
                onTap: () => setState(() => _lightning = !_lightning),
              ),
              _FilterButton(
                icon: PhosphorIconsRegular.link,
                active: _bitcoin,
                onTap: () => setState(() => _bitcoin = !_bitcoin),
              ),
              _FilterButton(
                icon: PhosphorIconsRegular.coinVertical,
                active: _ecash,
                onTap: () => setState(() => _ecash = !_ecash),
              ),
              _FilterButton(
                icon: PhosphorIconsRegular.plus,
                active: _incoming,
                onTap: () => setState(() => _incoming = !_incoming),
              ),
              _FilterButton(
                icon: PhosphorIconsRegular.minus,
                active: _outgoing,
                onTap: () => setState(() => _outgoing = !_outgoing),
              ),
            ],
          ),
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

class _FilterButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _FilterButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              active
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
        ),
        child: Icon(
          icon,
          size: smallIconSize,
          color: active ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
