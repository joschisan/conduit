import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AmountDisplay extends StatelessWidget {
  final int amount;

  const AmountDisplay(this.amount, {super.key});

  @override
  Widget build(BuildContext context) {
    final displayAmount = NumberFormat('#,###').format(amount);
    final textColor = Theme.of(context).colorScheme.onSurface;

    return RichText(
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
            text: ' sats',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
