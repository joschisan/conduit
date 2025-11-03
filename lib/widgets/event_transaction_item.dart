import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';

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

    // Determine icon based on status
    Widget leadingIcon = switch (event.success) {
      null => const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ), // Pending - spinner
      true => Icon(
        event.incoming ? Icons.arrow_downward : Icons.arrow_upward,
        color: Theme.of(context).colorScheme.primary,
        size: 26,
      ), // Success - arrow
      false => const Icon(
        Icons.error_outline,
        color: Colors.red,
        size: 26,
      ), // Failed - error icon
    };

    Color backgroundColor = switch (event.success) {
      null => Colors.grey.withOpacity(0.1), // Pending - grey
      true => Theme.of(context).colorScheme.primary.withOpacity(0.1), // Success
      false => Colors.red.withOpacity(0.1), // Failed - red tint
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
        leading: CircleAvatar(
          backgroundColor: backgroundColor,
          child: leadingIcon,
        ),
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
                      '$formattedAmount sats',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
                : Text(
                  '$formattedAmount sats',
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
