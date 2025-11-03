import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/utils/payment_type_utils.dart';
import 'package:conduit/widgets/icon_badge.dart';

String _formatTime(DateTime dateTime) {
  final difference = DateTime.now().difference(dateTime);

  return switch (difference) {
    _ when difference.inMinutes < 1 => 'Now',
    _ when difference.inMinutes < 60 => '${difference.inMinutes}m ago',
    _ when difference.inHours < 24 => '${difference.inHours}h ago',
    _ => '${difference.inDays}d ago',
  };
}

class EventTransactionItem extends StatelessWidget {
  final ConduitPayment event;
  final VoidCallback? onTap;

  const EventTransactionItem({super.key, required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.fromMillisecondsSinceEpoch(event.timestamp);
    final formattedAmount = NumberFormat('#,###').format(event.amountSats);
    final sign = event.incoming ? '+' : '-';

    Widget leading = switch (event.success) {
      null => IconBadge(
        iconSize: 26,
        color: Colors.grey,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ), // Pending - spinner
      true => IconBadge(
        icon: PaymentTypeUtils.getIcon(event.paymentType),
        iconSize: 26,
      ), // Success - payment type icon
      false => IconBadge(
        icon: Icons.error_outline,
        iconSize: 26,
        color: Colors.red,
      ), // Failed - error icon
    };

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 8.0,
          horizontal: 16.0,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: leading,
        title:
            event.incoming
                ? Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$sign $formattedAmount sats',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
                : Text(
                  '$sign $formattedAmount sats',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        trailing: Text(
          _formatTime(date),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
    );
  }
}
