import 'package:flutter/material.dart';
import 'package:conduit/widgets/amount_display_widget.dart';

class AmountCard extends StatelessWidget {
  final int amountSats;
  final int? feeSats;

  const AmountCard({super.key, required this.amountSats, this.feeSats});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: AmountDisplay(amountSats, fee: feeSats),
    );
  }
}
