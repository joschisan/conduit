import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
import 'package:intl/intl.dart';
import 'package:conduit/bridge_generated.dart/events.dart';
import 'package:conduit/utils/payment_utils.dart';
import 'package:conduit/utils/currency_utils.dart';
import 'package:conduit/widgets/amount_visibility.dart';
import 'package:conduit/widgets/icon_chip_widget.dart';

class PaymentCard extends StatelessWidget {
  final ConduitPayment event;
  final VoidCallback onTap;

  const PaymentCard({super.key, required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.fromMillisecondsSinceEpoch(event.timestamp);
    final formattedAmount = NumberFormat('#,###').format(event.amountSats);
    final sign = event.incoming ? '+' : '-';

    // In fiat mode show the value frozen at payment time, falling back to sats
    // for payments that carry no snapshot (predate the feature / no rate then).
    final fiat = historicalFiatParts(event);
    final (amountText, unitText) = switch (AmountDisplay.of(context)) {
      BalanceDisplay.hidden => (maskedAmount, 'sat'),
      BalanceDisplay.fiat when fiat != null => (
        '$sign${fiat.number}',
        fiat.unit,
      ),
      _ => ('$sign$formattedAmount', 'sat'),
    };

    // Failed payments are flagged by tinting the leading chip amber; the rest of
    // the row keeps its normal colours. Incoming funds show the amount in the
    // primary tint.
    final failed = event.success == false;
    Color? amountColor;
    if (!failed && event.incoming) {
      amountColor = Theme.of(context).colorScheme.primary;
    }

    final status = PaymentTypeUtils.getStatus(
      incoming: event.incoming,
      success: event.success,
    );

    final subColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return ListTile(
      onTap: onTap,
      contentPadding: listTilePadding,
      leading: IconChip(
        icon: PaymentTypeUtils.getDirectionIcon(event.incoming),
        color: failed ? Colors.amber : null,
      ),
      // Stack the header/subheader inside title (rather than using subtitle) so
      // the tile keeps its original single-line height instead of growing into
      // Material's taller two-line layout.
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                PaymentTypeUtils.getLabel(event.paymentType),
                style: mediumStyle,
              ),
              if (event.success == null) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          Text(
            '$status · ${formatRelativeTime(date)}',
            style: smallStyle.copyWith(color: subColor),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(amountText, style: mediumStyle.copyWith(color: amountColor)),
          Text(unitText, style: smallStyle.copyWith(color: subColor)),
        ],
      ),
    );
  }
}
