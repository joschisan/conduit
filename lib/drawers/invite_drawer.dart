import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
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
      icon: PhosphorIconsRegular.wallet,
      title: 'Federation Invite',
      children: [
        AsyncButton(text: 'Join', onPressed: () => onJoin(invite)),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => _showRecoverDrawer(context),
          child: Text(
            'Already used this federation before?',
            style: mediumStyle.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
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
      icon: PhosphorIconsRegular.wallet,
      title: 'Federation Invite',
      children: [
        AsyncButton(text: 'Recover', onPressed: () => onRecover(invite)),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => _showJoinDrawer(context),
          child: Text(
            'New to this federation?',
            style: mediumStyle.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
