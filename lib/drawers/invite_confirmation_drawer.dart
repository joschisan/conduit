import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/widgets/drawer_shell.dart';
import 'package:conduit/widgets/async_action_button.dart';
import 'package:conduit/utils/drawer_utils.dart';

class InviteConfirmationDrawer extends StatelessWidget {
  final InviteCodeWrapper invite;
  final Future<void> Function(InviteCodeWrapper) onJoin;
  final Future<void> Function(InviteCodeWrapper) onRecover;

  const InviteConfirmationDrawer({
    super.key,
    required this.invite,
    required this.onJoin,
    required this.onRecover,
  });

  static Future<void> show(
    BuildContext context, {
    required InviteCodeWrapper invite,
    required Future<void> Function(InviteCodeWrapper) onJoin,
    required Future<void> Function(InviteCodeWrapper) onRecover,
  }) {
    return DrawerUtils.show(
      context: context,
      child: InviteConfirmationDrawer(
        invite: invite,
        onJoin: onJoin,
        onRecover: onRecover,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DrawerShell(
      icon: Icons.link,
      title: 'Invite Code',
      children: [
        AsyncActionButton(text: 'Recover', onPressed: () => onRecover(invite)),
        const SizedBox(height: 12),
        AsyncActionButton(text: 'Join', onPressed: () => onJoin(invite)),
      ],
    );
  }
}
