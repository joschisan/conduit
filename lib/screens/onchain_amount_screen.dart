import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/widgets/amount_entry_widget.dart';
import 'package:conduit/utils/auth_utils.dart';

class OnchainAmountScreen extends StatefulWidget {
  final ConduitClient client;
  final BitcoinAddressWrapper address;

  const OnchainAmountScreen({
    super.key,
    required this.client,
    required this.address,
  });

  @override
  State<OnchainAmountScreen> createState() => _OnchainAmountScreenState();
}

class _OnchainAmountScreenState extends State<OnchainAmountScreen> {
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
        title: const Text('Onchain'),
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
                      return const Icon(
                        Icons.error,
                        color: Colors.red,
                        size: 28,
                      );
                    } else if (snapshot.hasData) {
                      return Text(
                        '${snapshot.data} sat',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
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
