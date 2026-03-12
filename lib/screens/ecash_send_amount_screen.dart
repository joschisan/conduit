import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/fountain.dart';
import 'package:conduit/widgets/amount_entry_widget.dart';
import 'package:conduit/screens/display_ecash_screen.dart';
import 'package:conduit/utils/auth_utils.dart';

class EcashSendAmountScreen extends StatelessWidget {
  final ConduitClient client;

  const EcashSendAmountScreen({super.key, required this.client});

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
              encoder: OobNotesEncoder(notes: notes),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('eCash')),
      body: SafeArea(
        child: AmountEntryWidget(
          client: client,
          onConfirm: (amountSats) => _handleConfirm(context, amountSats),
        ),
      ),
    );
  }
}
