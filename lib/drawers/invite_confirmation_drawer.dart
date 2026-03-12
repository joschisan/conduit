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
    final theme = Theme.of(context);
    return DrawerShell(
      icon: Icons.account_balance_wallet,
      title: 'Federation Invite',
      children: [
        Text(
          'New to this federation?',
          style: TextStyle(color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 8),
        AsyncActionButton(text: 'Join', onPressed: () => onJoin(invite)),
        const SizedBox(height: 24),
        Text(
          'Already used this federation before?',
          style: TextStyle(color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 8),
        AsyncActionButton(text: 'Recover', onPressed: () => onRecover(invite)),
      ],
    );
  }
}
