import 'package:conduit/widgets/balanced_text_widget.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/screens/federation_screen.dart';
import 'package:conduit/utils/notification_utils.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/drawers/invite_drawer.dart';
import 'package:conduit/drawers/invite_scanner_drawer.dart';
import 'package:conduit/drawers/recovery_drawer.dart';
import 'package:conduit/widgets/circular_action_button_widget.dart';

/// Observes page transitions so the home router can re-open the current
/// federation whenever it becomes visible again. Registered on the app's
/// [MaterialApp].
final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();

/// The app's root. With no federations it hosts onboarding (scan to join);
/// with at least one it immediately opens the current federation, so the
/// federation screen — not this screen — is what the user lands on and returns
/// to. Settings and federation switching now live on the federation screen.
class BaseScreen extends StatefulWidget {
  final ConduitClientFactory clientFactory;

  const BaseScreen({super.key, required this.clientFactory});

  @override
  State<BaseScreen> createState() => _BaseScreenState();
}

class _BaseScreenState extends State<BaseScreen> with RouteAware {
  List<FederationInfo> _federations = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();

    _refreshFederations(autoNavigate: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);

    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // Re-open the current federation whenever this router is revealed again —
  // e.g. after a recovery pushed a federation screen and the user popped back —
  // so it only ever routes forward.
  @override
  void didPopNext() {
    _refreshFederations(autoNavigate: true);
  }

  Future<void> _refreshFederations({bool autoNavigate = false}) async {
    final federations = await widget.clientFactory.listFederations();

    if (!mounted) return;

    setState(() {
      _federations = federations;
      _loaded = true;
    });

    if (autoNavigate && federations.isNotEmpty) {
      _openCurrentFederation(replace: true);
    }
  }

  // Opens the persisted active federation (falling back to the first one when
  // the stored selection is missing or gone). The screen resolves its own name.
  Future<void> _openCurrentFederation({bool replace = false}) async {
    try {
      final client = await widget.clientFactory.loadCurrent();

      if (!mounted) {
        client?.shutdown();
        return;
      }

      if (client == null) {
        NotificationUtils.showError(context, 'Failed to load mint');
        return;
      }

      _navigateToClientScreen(client, replace: replace);
    } catch (e) {
      if (mounted) NotificationUtils.showError(context, e.toString());
    }
  }

  void _navigateToClientScreen(
    ConduitClient client, {
    String? name,
    bool replace = false,
  }) {
    if (!mounted) return;

    // Only block on the recovery drawer when a module can't be used until its
    // recovery finishes. Otherwise open the wallet now and let it show recovery
    // progress on the federation row (see FederationScreen).
    if (client.hasPendingRecoveries() && !client.allModulesUsable()) {
      RecoveryDrawer.show(
        context,
        client: client,
        clientFactory: widget.clientFactory,
      );
      return;
    }

    final route = MaterialPageRoute<void>(
      builder:
          (_) => FederationScreen(
            client: client,
            clientFactory: widget.clientFactory,
            federationName: name,
          ),
    );

    if (replace) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
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

  Future<void> _handleJoinFederation(InviteCodeWrapper invite) async {
    final client = await widget.clientFactory.join(invite: invite);

    if (!mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);

    _navigateToClientScreen(client, replace: true);
  }

  Future<void> _handleRecoverFederation(InviteCodeWrapper invite) async {
    final client = await widget.clientFactory.recover(invite: invite);

    if (!mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);

    _navigateToClientScreen(client, replace: true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Conduit'),
      // Only offer paste on the onboarding view; otherwise this screen is a
      // blank router forwarding to the current federation.
      actions: [
        if (_loaded && _federations.isEmpty)
          IconButton(
            onPressed: _handlePasteInvite,
            icon: const Icon(PhosphorIconsRegular.clipboardText),
          ),
      ],
    ),
    // Blank until loaded, and while routing forward to a federation; the
    // onboarding card only shows once we know there are no federations.
    body:
        _loaded && _federations.isEmpty
            ? Center(child: _buildOnboardingCard())
            : const SizedBox.shrink(),
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
