import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/widgets/drawer_shell.dart';
import 'package:conduit/widgets/amount_card.dart';
import 'package:conduit/widgets/async_action_button.dart';
import 'package:conduit/utils/drawer_utils.dart';

class EcashReceiveDrawer extends StatefulWidget {
  final ConduitClient client;
  final OobNotesWrapper notes;

  const EcashReceiveDrawer({
    super.key,
    required this.client,
    required this.notes,
  });

  static Future<bool?> show(
    BuildContext context, {
    required ConduitClient client,
    required OobNotesWrapper notes,
  }) {
    return DrawerUtils.show<bool>(
      context: context,
      child: EcashReceiveDrawer(client: client, notes: notes),
    );
  }

  @override
  State<EcashReceiveDrawer> createState() => _EcashReceiveDrawerState();
}

class _EcashReceiveDrawerState extends State<EcashReceiveDrawer> {
  Future<void> _handleReceive() async {
    await widget.client.ecashReceive(notes: widget.notes);

    if (!mounted) return;

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DrawerShell(
      icon: Icons.toll,
      title: 'eCash',
      children: [
        AmountCard(amountSats: widget.notes.amountSats()),
        const SizedBox(height: 16),
        AsyncActionButton(text: 'Receive', onPressed: _handleReceive),
      ],
    );
  }
}
