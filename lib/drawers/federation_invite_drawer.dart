import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/widgets/drawer_shell.dart';
import 'package:conduit/widgets/qr_code_widget.dart';
import 'package:conduit/drawers/leave_federation_drawer.dart';
import 'package:conduit/utils/drawer_utils.dart';

class FederationInviteDrawer extends StatelessWidget {
  final FederationInfo federation;
  final ConduitClientFactory clientFactory;
  final VoidCallback onLeaveFederation;

  const FederationInviteDrawer({
    super.key,
    required this.federation,
    required this.clientFactory,
    required this.onLeaveFederation,
  });

  static Future<void> show(
    BuildContext context, {
    required FederationInfo federation,
    required ConduitClientFactory clientFactory,
    required VoidCallback onLeaveFederation,
  }) {
    return DrawerUtils.show(
      context: context,
      child: FederationInviteDrawer(
        federation: federation,
        clientFactory: clientFactory,
        onLeaveFederation: onLeaveFederation,
      ),
    );
  }

  void _handleLeave(BuildContext context) {
    Navigator.of(context).pop();
    LeaveFederationDrawer.show(
      context,
      federation: federation,
      clientFactory: clientFactory,
      onSuccess: onLeaveFederation,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DrawerShell(
      icon: Icons.account_balance_wallet,
      title: federation.name,
      topRightButton: IconButton(
        icon: const Icon(Icons.exit_to_app),
        onPressed: () => _handleLeave(context),
      ),
      children: [QrCodeWidget(data: federation.invite)],
    );
  }
}
