import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/widgets/amount_entry_widget.dart';
import 'package:conduit/screens/confirm_onchain_send_screen.dart';

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
  Future<void> _handleConfirm(int amountSats) async {
    final feeSats = await widget.client.onchainCalculateFees(
      address: widget.address,
      amountSats: amountSats,
    );

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => ConfirmOnchainSendScreen(
              client: widget.client,
              address: widget.address,
              amountSats: amountSats,
              feeSats: feeSats,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Onchain')),
      body: SafeArea(
        child: AmountEntryWidget(
          client: widget.client,
          onConfirm: _handleConfirm,
        ),
      ),
    );
  }
}
