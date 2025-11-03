import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/widgets/transaction_item.dart';

class TransactionsList extends StatelessWidget {
  final List<FTransaction> transactions;
  final void Function(FTransaction)? onTransactionTap;

  const TransactionsList({
    super.key,
    required this.transactions,
    this.onTransactionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Center(
        child: Text(
          'No transactions yet',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final tx = transactions[index];
        return TransactionItem(
          tx: tx,
          onTap: onTransactionTap != null ? () => onTransactionTap!(tx) : null,
        );
      },
    );
  }
}
