import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/widgets/amount_display_widget.dart';
import 'package:conduit/widgets/async_button_widget.dart';
import 'package:conduit/widgets/shareable_data_widget.dart';
import 'package:conduit/utils/auth_utils.dart';

class ConfirmOnchainSendScreen extends StatefulWidget {
  final ConduitClient client;
  final BitcoinAddressWrapper address;
  final int amountSats;
  final int feeSats;

  const ConfirmOnchainSendScreen({
    super.key,
    required this.client,
    required this.address,
    required this.amountSats,
    required this.feeSats,
  });

  @override
  State<ConfirmOnchainSendScreen> createState() =>
      _ConfirmOnchainSendScreenState();
}

class _ConfirmOnchainSendScreenState extends State<ConfirmOnchainSendScreen> {
  Future<void> _handleConfirm() async {
    await requireBiometricAuth(context);

    await widget.client.onchainSend(
      address: widget.address,
      amountSats: widget.amountSats,
    );

    if (!mounted) return;

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Onchain')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Spacer(),
              Icon(
                PhosphorIconsRegular.link,
                size: heroIconSize,
                color: Theme.of(context).colorScheme.primary,
              ),
              const Spacer(),
              AmountDisplay(widget.amountSats, fee: widget.feeSats),
              const Spacer(flex: 2),
              ShareableData(data: widget.address.toString()),
              const SizedBox(height: 16),
              AsyncButton(text: 'Confirm', onPressed: _handleConfirm),
            ],
          ),
        ),
      ),
    );
  }
}
