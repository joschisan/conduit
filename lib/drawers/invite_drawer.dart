import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/widgets/drawer_shell_widget.dart';
import 'package:conduit/widgets/async_button_widget.dart';
import 'package:conduit/utils/drawer_utils.dart';

class InviteDrawer extends StatelessWidget {
  final InviteCodeWrapper invite;
  final Future<void> Function(InviteCodeWrapper) onJoin;
  final Future<void> Function(InviteCodeWrapper) onRecover;

  const InviteDrawer({
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
      child: InviteDrawer(invite: invite, onJoin: onJoin, onRecover: onRecover),
    );
  }

  void _showRecoverDrawer(BuildContext context) {
    Navigator.of(context).pop();
    DrawerUtils.show(
      context: context,
      child: _RecoverDrawer(
        invite: invite,
        onJoin: onJoin,
        onRecover: onRecover,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DrawerShell(
      icon: Icons.account_balance_wallet,
      title: 'Federation Invite',
      children: [
        GestureDetector(
          onTap: () => _showRecoverDrawer(context),
          child: Text(
            'Already used this federation before?',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        AsyncButton(text: 'Join', onPressed: () => onJoin(invite)),
      ],
    );
  }
}

class _RecoverDrawer extends StatelessWidget {
  final InviteCodeWrapper invite;
  final Future<void> Function(InviteCodeWrapper) onJoin;
  final Future<void> Function(InviteCodeWrapper) onRecover;

  const _RecoverDrawer({
    required this.invite,
    required this.onJoin,
    required this.onRecover,
  });

  void _showJoinDrawer(BuildContext context) {
    Navigator.of(context).pop();
    InviteDrawer.show(
      context,
      invite: invite,
      onJoin: onJoin,
      onRecover: onRecover,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DrawerShell(
      icon: Icons.account_balance_wallet,
      title: 'Federation Invite',
      children: [
        GestureDetector(
          onTap: () => _showJoinDrawer(context),
          child: Text(
            'New to this federation?',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        AsyncButton(text: 'Recover', onPressed: () => onRecover(invite)),
      ],
    );
  }
}
