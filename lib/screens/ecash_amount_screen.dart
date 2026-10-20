import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/fountain.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/widgets/amount_entry_widget.dart';
import 'package:conduit/widgets/max_action_widget.dart';
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

    _display(context, notes);
  }

  /// Spends the notes themselves, so the bundle is for whatever the account
  /// holds rather than for a figure in sats. An empty account, or a mint
  /// that cannot offer it, throws and reaches the user as a notification.
  Future<void> _handleConfirmMax(BuildContext context) async {
    await requireBiometricAuth(context);

    final notes = await client.ecashSendMax();

    if (!context.mounted) return;

    _display(context, notes);
  }

  /// Hands the notes to the screen that shows them. Until it has them they
  /// are held nowhere else: the send returned them by value and took them
  /// out of the account.
  void _display(BuildContext context, ECashWrapper notes) {
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
      appBar: AppBar(
        title: const Text('Send eCash'),
        actions: [MaxAction(onPressed: () => _handleConfirmMax(context))],
      ),
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
