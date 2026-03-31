import 'package:phosphor_flutter/phosphor_flutter.dart';
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

    Color? titleColor;
    if (event.success == false) {
      titleColor = Colors.red;
    } else if (event.incoming) {
      titleColor = Theme.of(context).colorScheme.primary;
    }

    Widget leading = switch (event.success) {
      null => LoadingIcon(key: const ValueKey('loading'), icon: icon),
      true => KeyedSubtree(key: const ValueKey('success'), child: icon),
      false => const Icon(
        PhosphorIconsRegular.warningCircle,
        size: mediumIconSize,
        color: Colors.red,
      ),
    };

    return ListTile(
      onTap: onTap,
      contentPadding: listTilePadding,
      leading: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        child: leading,
      ),
      title: Text(
        '$sign $formattedAmount sat',
        style: mediumStyle.copyWith(color: titleColor),
      ),
      trailing: Text(
        _formatTime(date),
        style: smallStyle.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
