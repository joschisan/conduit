import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/utils/notification_utils.dart';
import 'package:conduit/widgets/qr_scanner_widget.dart';
import 'package:conduit/drawers/invite_confirmation_drawer.dart';
import 'package:conduit/utils/drawer_utils.dart';

class InviteScannerDrawer extends StatefulWidget {
  final ConduitClientFactory clientFactory;
  final Future<void> Function(InviteCodeWrapper) onJoin;
  final Future<void> Function(InviteCodeWrapper) onRecover;

  const InviteScannerDrawer({
    super.key,
    required this.clientFactory,
    required this.onJoin,
    required this.onRecover,
  });

  static Future<void> show(
    BuildContext context, {
    required ConduitClientFactory clientFactory,
    required Future<void> Function(InviteCodeWrapper) onJoin,
    required Future<void> Function(InviteCodeWrapper) onRecover,
  }) {
    return DrawerUtils.show(
      context: context,
      child: InviteScannerDrawer(
        clientFactory: clientFactory,
        onJoin: onJoin,
        onRecover: onRecover,
      ),
    );
  }

  @override
  State<InviteScannerDrawer> createState() => _InviteScannerDrawerState();
}

class _InviteScannerDrawerState extends State<InviteScannerDrawer> {
  bool _isScanning = true;

  void _processInput(String invite) {
    if (!_isScanning) return;

    final inviteCode = parseInviteCode(invite: invite);

    if (inviteCode != null) {
      _isScanning = false;
      Navigator.of(context).pop();

      InviteConfirmationDrawer.show(
        context,
        invite: inviteCode,
        onJoin: widget.onJoin,
        onRecover: widget.onRecover,
      );
      return;
    }

    if (mounted) {
      NotificationUtils.showError(context, 'Failed to parse invite code');
    }
  }

  @override
  Widget build(BuildContext context) {
    return QrScannerWidget(onScan: _processInput);
  }
}
