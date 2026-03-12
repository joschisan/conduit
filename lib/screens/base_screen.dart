import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/screens/federation_screen.dart';
import 'package:conduit/screens/display_recovery_phrase_screen.dart';
import 'package:conduit/screens/select_currency_screen.dart';
import 'package:conduit/utils/notification_utils.dart';
import 'package:conduit/utils/auth_utils.dart';
import 'package:conduit/drawers/invite_scanner_drawer.dart';
import 'package:conduit/drawers/leave_federation_drawer.dart';
import 'package:conduit/drawers/recovery_drawer.dart';
import 'package:conduit/widgets/settings_card_widget.dart';

class BaseScreen extends StatefulWidget {
  final ConduitClientFactory clientFactory;
  final ConduitClient? initialClient;

  const BaseScreen({
    super.key,
    required this.clientFactory,
    this.initialClient,
  });

  @override
  State<BaseScreen> createState() => _BaseScreenState();
}

class _BaseScreenState extends State<BaseScreen> {
  late Future<List<FederationInfo>> _federationsFuture;

  @override
  void initState() {
    super.initState();

    _refreshFederations();

    if (widget.initialClient != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToClientScreen(widget.initialClient!);
      });
    }
  }

  void _refreshFederations() {
    setState(() {
      _federationsFuture = widget.clientFactory.listFederations();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Conduit')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<List<FederationInfo>>(
          future: _federationsFuture,
          builder: (context, snapshot) {
            final federations = snapshot.data ?? [];
            final showOnboarding = snapshot.hasData && federations.isEmpty;

            final theme = Theme.of(context);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Settings', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                _buildSeedPhraseCard(),
                const SizedBox(height: 4),
                _buildCurrencyCard(),
                const SizedBox(height: 24),
                if (showOnboarding)
                  _buildOnboardingCard()
                else
                  _buildFederationsContent(snapshot),
              ],
            );
          },
        ),
      ),
    ),
  );

  Widget _buildOnboardingCard() {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text('Federations', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'A federation is a group of trusted guardians who collectively custody bitcoin for their community in a multisig wallet.'
              '\n\n'
              'The guardians cannot tell which payments belong to you or what balance you have.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _showScannerDrawer,
              child: Text(
                'Add Federation',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFederationsContent(
    AsyncSnapshot<List<FederationInfo>> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return _buildLoadingState();
    }

    if (snapshot.hasError) {
      return _buildErrorState();
    }

    final federations = snapshot.data ?? [];
    return _buildFederationsListView(federations);
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildErrorState() {
    return Center(
      child: Text(
        'Error loading federations',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  Widget _buildFederationsListView(List<FederationInfo> federations) {
    if (federations.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Federations', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          itemCount: federations.length,
          itemBuilder: (context, index) {
            final federation = federations[index];
            return _buildFederationCard(federation);
          },
        ),
        Center(
          child: TextButton(
            onPressed: _showScannerDrawer,
            child: Text(
              'Add Federation',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showScannerDrawer() {
    InviteScannerDrawer.show(
      context,
      clientFactory: widget.clientFactory,
      onJoin: _handleJoinFederation,
      onRecover: _handleRecoverFederation,
    );
  }

  void _navigateToClientScreen(ConduitClient client) {
    if (!mounted) return;

    if (client.hasPendingRecoveries()) {
      RecoveryDrawer.show(
        context,
        client: client,
        clientFactory: widget.clientFactory,
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => FederationScreen(
                client: client,
                clientFactory: widget.clientFactory,
              ),
        ),
      );
    }
  }

  Future<void> _handleJoinFederation(InviteCodeWrapper invite) async {
    final client = await widget.clientFactory.join(invite: invite);

    _refreshFederations();

    if (!mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);

    _navigateToClientScreen(client);
  }

  Future<void> _handleRecoverFederation(InviteCodeWrapper invite) async {
    final client = await widget.clientFactory.recover(invite: invite);

    _refreshFederations();

    if (!mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);

    _navigateToClientScreen(client);
  }

  Widget _buildSeedPhraseCard() {
    return SettingsCard(
      icon: Icons.key,
      title: 'Recovery Phrase',
      onTap: _handleSeedPhraseTap,
    );
  }

  Widget _buildCurrencyCard() {
    return SettingsCard(
      icon: Icons.currency_exchange,
      title: 'Select Currency',
      onTap: _handleCurrencyTap,
    );
  }

  Widget _buildFederationCard(FederationInfo federation) {
    return SettingsCard(
      icon: Icons.account_balance_wallet,
      title: federation.name,
      onTap: () => _handleFederationTap(federation),
      onLongPress: () => _showLeaveFederationDrawer(federation),
    );
  }

  Future<void> _handleFederationTap(FederationInfo federation) async {
    try {
      final client = await widget.clientFactory.load(
        federationId: federation.id,
      );

      if (client == null) {
        if (mounted) {
          NotificationUtils.showError(context, 'Failed to load federation');
        }
        return;
      }

      _navigateToClientScreen(client);
    } catch (e) {
      if (mounted) {
        NotificationUtils.showError(context, e.toString());
      }
    }
  }

  void _showLeaveFederationDrawer(FederationInfo federation) {
    LeaveFederationDrawer.show(
      context,
      federation: federation,
      clientFactory: widget.clientFactory,
      onSuccess: _refreshFederations,
    );
  }

  Future<void> _handleCurrencyTap() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => SelectCurrencyScreen(clientFactory: widget.clientFactory),
      ),
    );
  }

  Future<void> _handleSeedPhraseTap() async {
    try {
      await requireBiometricAuth(context);

      if (!mounted) return;

      final seedPhrase = await widget.clientFactory.seedPhrase();

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DisplayRecoveryPhraseScreen(seedPhrase: seedPhrase),
        ),
      );
    } catch (e) {
      if (mounted) {
        NotificationUtils.showError(context, e.toString());
      }
    }
  }
}
