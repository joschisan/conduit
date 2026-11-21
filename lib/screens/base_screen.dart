import 'dart:async';

import 'package:conduit/widgets/balanced_text_widget.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/screens/home_screen.dart';
import 'package:conduit/utils/notification_utils.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/drawers/invite_drawer.dart';
import 'package:conduit/drawers/invite_scanner_drawer.dart';
import 'package:conduit/widgets/circular_action_button_widget.dart';

/// Where a wallet with no mint lands. Adding one — by scanning or pasting an
/// invite — is the only thing to do here, so the screen is just that: the
/// reason and the action.
///
/// Watches for the first mint and hands the wallet to [HomeScreen] for good —
/// removing the last mint is blocked, so nothing comes back here short of a
/// restart with an empty wallet.
class BaseScreen extends StatefulWidget {
  final ConduitClientFactory clientFactory;

  const BaseScreen({super.key, required this.clientFactory});

  @override
  State<BaseScreen> createState() => _BaseScreenState();
}

class _BaseScreenState extends State<BaseScreen> {
  StreamSubscription<List<ConduitClient>>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.clientFactory.subscribeClients().listen((clients) {
      if (!mounted || clients.isEmpty) return;
      // Clears the scanner and invite drawers along with this screen, so the
      // wallet lands on the home screen with nothing stacked behind it. The
      // invite drawer's own pop is a no-op once its route is gone.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder:
              (_) => HomeScreen(
                clientFactory: widget.clientFactory,
                initialClients: clients,
              ),
        ),
        (_) => false,
      );
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _showScannerDrawer() async {
    InviteScannerDrawer.show(
      context,
      clientFactory: widget.clientFactory,
      onJoin: _handleJoinFederation,
      onRecover: _handleRecoverFederation,
    );
  }

  // Onboarding paste: read the clipboard and, if it holds an invite code, open
  // the join/restore drawer — the keyboard-less alternative to scanning.
  Future<void> _handlePasteInvite() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboardData?.text;

    if (!mounted) return;

    if (text == null || text.isEmpty) {
      NotificationUtils.showError(context, 'Failed to access clipboard');
      return;
    }

    final inviteCode = parseInviteCode(invite: text);

    if (inviteCode == null) {
      NotificationUtils.showError(context, 'Failed to parse invite code');
      return;
    }

    InviteDrawer.show(
      context,
      invite: inviteCode,
      onJoin: _handleJoinFederation,
      onRecover: _handleRecoverFederation,
    );
  }

  // Nothing to navigate: the client stream above does that once the mint's
  // clients are open.
  Future<void> _handleJoinFederation(InviteCodeWrapper invite) =>
      widget.clientFactory.join(invite: invite);

  Future<void> _handleRecoverFederation(InviteCodeWrapper invite) =>
      widget.clientFactory.recover(invite: invite);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Conduit'),
      actions: [
        IconButton(
          onPressed: _handlePasteInvite,
          icon: const Icon(PhosphorIconsRegular.clipboardText),
        ),
      ],
    ),
    body: Center(child: _buildOnboardingCard()),
  );

  Widget _buildOnboardingCard() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: BalancedText(
            'Add a mint to transact.',
            textAlign: TextAlign.center,
            style: smallStyle,
          ),
        ),
        const SizedBox(height: 16),
        CircularActionButton(
          icon: PhosphorIconsRegular.qrCode,
          label: 'Scan',
          onTap: _showScannerDrawer,
        ),
      ],
    );
  }
}
