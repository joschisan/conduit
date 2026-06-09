import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
import 'package:intl/intl.dart';

class AmountDisplay extends StatelessWidget {
  final int amount;

  const AmountDisplay(this.amount, {super.key});

  @override
  Widget build(BuildContext context) {
    final displayAmount = NumberFormat('#,###').format(amount);

    return Text.rich(
      textAlign: TextAlign.center,
      TextSpan(
        children: [
          TextSpan(text: displayAmount, style: heroStyle),
          TextSpan(text: ' sat', style: largeStyle),
        ],
      ),
    );
  }
}
