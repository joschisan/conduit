import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/widgets/amount_entry_widget.dart';
import 'package:conduit/utils/auth_utils.dart';

class LnurlPaymentAmountScreen extends StatelessWidget {
  final ConduitClient client;
  final LnurlPayInfo payInfo;

  const LnurlPaymentAmountScreen({
    super.key,
    required this.client,
    required this.payInfo,
  });

  Future<void> _handleConfirm(BuildContext context, int amountSats) async {
    // Resolve LNURL to get invoice (with bounds checking)
    final invoice = await lnurlResolve(payInfo: payInfo, amountSats: amountSats);

    if (!context.mounted) return;

    // Require biometric authentication
    await requireBiometricAuth(context);

    await client.lnSend(invoice: invoice);

    if (!context.mounted) return;

    // Go back to home after successful payment
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: AmountEntryWidget(
          client: client,
          onConfirm: (amountSats) => _handleConfirm(context, amountSats),
        ),
      ),
    );
  }
}
