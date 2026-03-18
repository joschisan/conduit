import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
import 'package:intl/intl.dart';
import 'package:conduit/bridge_generated.dart/events.dart';
import 'package:conduit/utils/payment_utils.dart';
import 'package:conduit/widgets/loading_icon_widget.dart';

String _formatTime(DateTime dateTime) {
  final difference = DateTime.now().difference(dateTime);

  return switch (difference) {
    _ when difference.inMinutes < 1 => 'Now',
    _ when difference.inMinutes < 60 => '${difference.inMinutes}m ago',
    _ when difference.inHours < 24 => '${difference.inHours}h ago',
    _ => '${difference.inDays}d ago',
  };
}

class PaymentCard extends StatelessWidget {
  final ConduitPayment event;
  final VoidCallback onTap;

  const PaymentCard({super.key, required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.fromMillisecondsSinceEpoch(event.timestamp);
    final formattedAmount = NumberFormat('#,###').format(event.amountSats);
    final sign = event.incoming ? '+' : '-';

    final icon = Icon(
      PaymentTypeUtils.getIcon(event.paymentType),
      size: mediumIconSize,
      color: Theme.of(context).colorScheme.primary,
    );

    Widget leading = switch (event.success) {
      null => LoadingIcon(icon: icon),
      true => icon,
      false => const Icon(Icons.error, size: mediumIconSize, color: Colors.red),
    };

    return ListTile(
      onTap: onTap,
      contentPadding: listTilePadding,
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
                    color:
                        event.success == false
                            ? Colors.red
                            : Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$sign $formattedAmount sat',
                    style: mediumStyle.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              )
              : Text('$sign $formattedAmount sat', style: mediumStyle),
      trailing: Text(
        _formatTime(date),
        style: smallStyle.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
