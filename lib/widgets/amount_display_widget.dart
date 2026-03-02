import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AmountDisplay extends StatelessWidget {
  final int amount;
  final int? fee;

  const AmountDisplay(this.amount, {this.fee, super.key});

  @override
  Widget build(BuildContext context) {
    final displayAmount = NumberFormat('#,###').format(amount);
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: displayAmount,
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              TextSpan(
                text: ' sat',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
        if (fee != null) ...[
          const SizedBox(height: 8),
          Text(
            '${NumberFormat('#,###').format(fee)} sat',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ],
    );
  }
}
