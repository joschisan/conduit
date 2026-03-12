import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
import 'package:intl/intl.dart';

class AmountDisplay extends StatelessWidget {
  final int amount;
  final int? fee;

  const AmountDisplay(this.amount, {this.fee, super.key});

  @override
  Widget build(BuildContext context) {
    final displayAmount = NumberFormat('#,###').format(amount);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          textAlign: TextAlign.center,
          TextSpan(
            children: [
              TextSpan(text: displayAmount, style: heroStyle),
              TextSpan(text: ' sat', style: largeStyle),
            ],
          ),
        ),
        if (fee != null) ...[
          const SizedBox(height: 8),
          Text(
            '${NumberFormat('#,###').format(fee)} sat',
            style: largeStyle.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ],
    );
  }
}
