import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/fountain.dart';
import 'package:conduit/widgets/amount_entry_widget.dart';
import 'package:conduit/screens/display_ecash_screen.dart';
import 'package:conduit/utils/auth_utils.dart';

class EcashAmountScreen extends StatelessWidget {
  final ConduitClient client;
  final bool fiat;

  const EcashAmountScreen({super.key, required this.client, this.fiat = false});

  Future<void> _handleConfirm(BuildContext context, int amountSats) async {
    await requireBiometricAuth(context);

    final notes = await client.ecashSend(amountSat: amountSats);

    if (!context.mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder:
            (_) => DisplayEcashScreen(
              client: client,
              notes: notes,
              encoder: ECashEncoder(notes: notes),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send eCash')),
      body: SafeArea(
        child: AmountEntryWidget(
          client: client,
          fiat: fiat,
          onConfirm: (amountSats) => _handleConfirm(context, amountSats),
        ),
      ),
    );
  }
}
