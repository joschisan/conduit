import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/widgets/drawer_shell.dart';
import 'package:conduit/widgets/async_action_button.dart';
import 'package:conduit/utils/drawer_utils.dart';

class LeaveFederationDrawer extends StatefulWidget {
  final FederationInfo federation;
  final ConduitClientFactory clientFactory;
  final VoidCallback onSuccess;

  const LeaveFederationDrawer({
    super.key,
    required this.federation,
    required this.clientFactory,
    required this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required FederationInfo federation,
    required ConduitClientFactory clientFactory,
    required VoidCallback onSuccess,
  }) {
    return DrawerUtils.show(
      context: context,
      child: LeaveFederationDrawer(
        federation: federation,
        clientFactory: clientFactory,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<LeaveFederationDrawer> createState() => _LeaveFederationDrawerState();
}

class _LeaveFederationDrawerState extends State<LeaveFederationDrawer> {
  Future<void> _handleLeaveFederation() async {
    await widget.clientFactory.leave(federationId: widget.federation.id);

    if (!mounted) return;

    Navigator.of(context).pop();
    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    return DrawerShell(
      icon: Icons.exit_to_app,
      title: 'Leave ${widget.federation.name}?',
      children: [
        AsyncActionButton(text: 'Confirm', onPressed: _handleLeaveFederation),
      ],
    );
  }
}
