import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart' hide State;
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/widgets/invite_scanner_widget.dart';
import 'package:conduit/widgets/async_action_button.dart';
import 'package:conduit/widgets/qr_code_widget.dart';
import 'package:conduit/widgets/copy_button.dart';
import 'package:conduit/screens/home_screen.dart';
import 'package:conduit/screens/recovery_screen.dart';
import 'package:conduit/screens/display_seed_screen.dart';
import 'package:conduit/screens/currency_selection_screen.dart';
import 'package:conduit/utils/notification_utils.dart';
import 'package:conduit/utils/fp_utils.dart';
import 'package:conduit/utils/auth_utils.dart';
import 'package:conduit/utils/drawer_utils.dart';

class SettingsScreen extends StatefulWidget {
  final ConduitClientFactory clientFactory;

  const SettingsScreen({super.key, required this.clientFactory});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<List<FederationInfo>> _federationsFuture;

  @override
  void initState() {
    super.initState();
    _refreshFederations();
  }

  void _refreshFederations() {
    setState(() {
      _federationsFuture = widget.clientFactory.listFederations();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Settings'),
      actions: [
        IconButton(
          icon: const Icon(Icons.qr_code_scanner),
          onPressed: _showScannerDrawer,
        ),
      ],
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSeedPhraseCard(),
            const SizedBox(height: 4),
            _buildCurrencyCard(),
            const Spacer(),
            FutureBuilder<List<FederationInfo>>(
              future: _federationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading federations',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  );
                }

                final federations = snapshot.data ?? [];

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: federations.length,
                  itemBuilder: (context, index) {
                    final federation = federations[index];
                    return _buildFederationCard(federation);
                  },
                );
              },
            ),
          ],
        ),
      ),
    ),
  );

  void _showScannerDrawer() {
    showStandardDrawer(
      context: context,
      child: InviteScannerWidget(
        clientFactory: widget.clientFactory,
        onJoin: _handleJoinFederation,
        onRecover: _handleRecoverFederation,
      ),
    );
  }

  TaskEither<String, void> _handleJoinFederation(InviteCodeWrapper invite) {
    return safeTask(() async {
      final client = await widget.clientFactory.join(invite: invite);

      _refreshFederations();

      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);

      // Check if recovery is needed
      if (client.hasPendingRecoveries()) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) => RecoveryScreen(
                  client: client,
                  clientFactory: widget.clientFactory,
                ),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder:
                (_) => HomeScreen(
                  client: client,
                  clientFactory: widget.clientFactory,
                ),
          ),
        );
      }
    });
  }

  TaskEither<String, void> _handleRecoverFederation(InviteCodeWrapper invite) {
    return safeTask(() async {
      final client = await widget.clientFactory.recover(invite: invite);

      _refreshFederations();

      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);

      // Check if recovery is needed
      if (client.hasPendingRecoveries()) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) => RecoveryScreen(
                  client: client,
                  clientFactory: widget.clientFactory,
                ),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder:
                (_) => HomeScreen(
                  client: client,
                  clientFactory: widget.clientFactory,
                ),
          ),
        );
      }
    });
  }

  Widget _buildSeedPhraseCard() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 8.0,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(Icons.key, color: Theme.of(context).colorScheme.primary),
        ),
        title: const Text('Seed Phrase'),
        trailing: const Icon(Icons.chevron_right),
        onTap: _handleSeedPhraseTap,
      ),
    );
  }

  Widget _buildCurrencyCard() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 8.0,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(
            Icons.attach_money,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: const Text('Select Currency'),
        trailing: const Icon(Icons.chevron_right),
        onTap: _handleCurrencyTap,
      ),
    );
  }

  Widget _buildFederationCard(FederationInfo federation) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 8.0,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(
            Icons.account_balance_wallet,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(federation.name),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _handleFederationTap(federation),
        onLongPress: () => _showInviteCodeDrawer(federation),
      ),
    );
  }

  Future<void> _handleFederationTap(FederationInfo federation) async {
    try {
      final client = await widget.clientFactory.load(
        federationId: federation.id,
      );

      if (client == null) {
        _showError('Failed to load federation');
        return;
      }

      if (!mounted) return;

      // Check if recovery is needed
      if (client.hasPendingRecoveries()) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) => RecoveryScreen(
                  client: client,
                  clientFactory: widget.clientFactory,
                ),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder:
                (_) => HomeScreen(
                  client: client,
                  clientFactory: widget.clientFactory,
                ),
          ),
        );
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showInviteCodeDrawer(FederationInfo federation) {
    showStandardDrawer(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.account_balance_wallet,
                      color: Theme.of(context).colorScheme.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(federation.name, style: const TextStyle(fontSize: 18)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.exit_to_app),
                onPressed: () {
                  Navigator.of(context).pop();
                  _showLeaveFederationDrawer(federation);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          QrCodeWidget(data: federation.invite),
          const SizedBox(height: 16),
          CopyButton(data: federation.invite, message: 'Invite code copied!'),
        ],
      ),
    );
  }

  void _showLeaveFederationDrawer(FederationInfo federation) {
    showStandardDrawer(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                child: Icon(
                  Icons.exit_to_app,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Leave ${federation.name}?',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AsyncActionButton(
            text: 'Confirm',
            onPressed: () => _handleLeaveFederation(federation.id),
            onSuccess: () {
              Navigator.of(context).pop();
              _refreshFederations();
            },
          ),
        ],
      ),
    );
  }

  TaskEither<String, void> _handleLeaveFederation(FederationId federationId) {
    return safeTask(
      () => widget.clientFactory.leave(federationId: federationId),
    );
  }

  Future<void> _handleCurrencyTap() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => CurrencySelectionScreen(clientFactory: widget.clientFactory),
      ),
    );
  }

  Future<void> _handleSeedPhraseTap() async {
    try {
      final authenticated = await requireBiometricAuth(
        context,
        'Please authenticate to view your seed phrase',
      );

      if (!authenticated) {
        return;
      }

      if (!mounted) return;

      final seedPhrase = await widget.clientFactory.seedPhrase();

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DisplaySeedScreen(seedPhrase: seedPhrase),
        ),
      );
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    if (mounted) {
      NotificationUtils.showError(context, message);
    }
  }
}
