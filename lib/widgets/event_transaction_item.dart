import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:conduit/bridge_generated.dart/events.dart';
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

class EventTransactionItem extends StatefulWidget {
  final ConduitPayment event;
  final VoidCallback onTap;
  final bool animate;

  const EventTransactionItem({
    super.key,
    required this.event,
    required this.animate,
    required this.onTap,
  });

  @override
  State<EventTransactionItem> createState() => _EventTransactionItemState();
}

class _EventTransactionItemState extends State<EventTransactionItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0; // Skip animation for existing items
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime.fromMillisecondsSinceEpoch(widget.event.timestamp);
    final formattedAmount = NumberFormat(
      '#,###',
    ).format(widget.event.amountSats);
    final sign = widget.event.incoming ? '+' : '-';

    Widget leading = switch (widget.event.success) {
      null => Stack(
        alignment: Alignment.center,
        children: [
          IconBadge(
            icon: PaymentTypeUtils.getIcon(widget.event.paymentType),
            iconSize: 26,
          ),
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ), // Pending - icon with spinner on rim
      true => IconBadge(
        icon: PaymentTypeUtils.getIcon(widget.event.paymentType),
        iconSize: 26,
      ), // Success - payment type icon
      false => IconBadge(
        icon: Icons.error_outline,
        iconSize: 26,
        color: Colors.red,
      ), // Failed - error icon
    };

    return SizeTransition(
      sizeFactor: CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutCubic,
      ),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: ListTile(
            onTap: widget.onTap,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 16.0,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: leading,
            title:
                widget.event.incoming
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
        ),
      ),
    );
  }
}
