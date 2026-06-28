import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/events.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/utils/payment_utils.dart';
import 'package:conduit/widgets/icon_chip_widget.dart';

/// The leading "summary" row of a payment drawer: a direction-arrow chip with
/// the rail as the header and an action/status line beneath — mirroring the
/// payment tile, folded in as the first row of the detail list.
class PaymentSummaryRow extends StatelessWidget {
  final PaymentType paymentType;
  final bool incoming;
  final String status;
  final Color? iconColor;

  const PaymentSummaryRow({
    super.key,
    required this.paymentType,
    required this.incoming,
    required this.status,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: listTilePadding,
      leading: IconChip(
        icon: PaymentTypeUtils.getDirectionIcon(incoming),
        color: iconColor,
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(PaymentTypeUtils.getLabel(paymentType), style: mediumStyle),
          Text(
            status,
            style: smallStyle.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
