import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/widgets/drawer_shell.dart';
import 'package:conduit/widgets/async_action_button.dart';
import 'package:conduit/utils/drawer_utils.dart';

class CancelEcashDrawer extends StatelessWidget {
  final ConduitClient client;
  final OobNotesWrapper notes;

  const CancelEcashDrawer({
    super.key,
    required this.client,
    required this.notes,
  });

  static Future<void> show(
    BuildContext context, {
    required ConduitClient client,
    required OobNotesWrapper notes,
  }) {
    return DrawerUtils.show(
      context: context,
      child: CancelEcashDrawer(client: client, notes: notes),
    );
  }

  Future<void> _handleConfirm(BuildContext context) async {
    await client.ecashReceive(notes: notes);

    if (!context.mounted) return;

    Navigator.of(context).pop(); // Close drawer
    Navigator.of(context).pop(); // Return to home screen
  }

  @override
  Widget build(BuildContext context) {
    return DrawerShell(
      icon: Icons.close,
      title: 'Cancel Payment?',
      children: [
        AsyncActionButton(
          text: 'Confirm',
          onPressed: () => _handleConfirm(context),
        ),
      ],
    );
  }
}
