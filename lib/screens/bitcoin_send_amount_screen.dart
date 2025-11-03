import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/widgets/amount_entry_widget.dart';
import 'package:conduit/utils/auth_utils.dart';

class BitcoinSendAmountScreen extends StatefulWidget {
  final ConduitClient client;
  final BitcoinAddressWrapper address;

  const BitcoinSendAmountScreen({
    super.key,
    required this.client,
    required this.address,
  });

  @override
  State<BitcoinSendAmountScreen> createState() =>
      _BitcoinSendAmountScreenState();
}

class _BitcoinSendAmountScreenState extends State<BitcoinSendAmountScreen> {
  Future<int>? _feeFuture;

  void _onAmountChanged(int currentAmount) {
    if (currentAmount == 0) {
      setState(() {
        _feeFuture = null;
      });
    } else {
      setState(() {
        _feeFuture = widget.client.onchainCalculateFees(
          address: widget.address,
          amountSats: currentAmount,
        );
      });
    }
  }

  Future<void> _handleConfirm(BuildContext context, int amountSats) async {
    // Require biometric authentication
    await requireBiometricAuth(context);

    await widget.client.onchainSend(
      address: widget.address,
      amountSats: amountSats,
    );

    if (!context.mounted) return;

    // Go back after successful send
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (_feeFuture != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: FutureBuilder<int>(
                  future: _feeFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    } else if (snapshot.hasError) {
                      return const Text(
                        'Failed to calculate fee',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      );
                    } else if (snapshot.hasData) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          'Fee: ${snapshot.data} sats',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: AmountEntryWidget(
          client: widget.client,
          onConfirm: (amountSats) => _handleConfirm(context, amountSats),
          onAmountChanged: _onAmountChanged,
        ),
      ),
    );
  }
}
