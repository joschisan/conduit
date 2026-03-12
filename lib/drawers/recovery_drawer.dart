import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/widgets/drawer_shell_widget.dart';
import 'package:conduit/utils/drawer_utils.dart';
import 'package:conduit/screens/federation_screen.dart';

class RecoveryDrawer extends StatefulWidget {
  final ConduitClient client;
  final ConduitClientFactory clientFactory;

  const RecoveryDrawer({
    super.key,
    required this.client,
    required this.clientFactory,
  });

  static Future<void> show(
    BuildContext context, {
    required ConduitClient client,
    required ConduitClientFactory clientFactory,
  }) {
    return DrawerUtils.show(
      context: context,
      child: RecoveryDrawer(client: client, clientFactory: clientFactory),
    );
  }

  @override
  State<RecoveryDrawer> createState() => _RecoveryDrawerState();
}

class _RecoveryDrawerState extends State<RecoveryDrawer> {
  late final Future<void> _recoveryFuture;

  @override
  void initState() {
    super.initState();
    _recoveryFuture = _performRecovery();
  }

  Future<void> _performRecovery() async {
    await widget.client.waitForAllRecoveries();

    // Reload the client to get a fresh instance after recovery
    final newClient = await widget.clientFactory.load(
      federationId: widget.client.federationId(),
    );

    // Defer navigation until after the current frame completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Navigator.of(context).pop(); // Close drawer

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (_) => FederationScreen(
                client: newClient!,
                clientFactory: widget.clientFactory,
              ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _recoveryFuture,
      builder: (context, snapshot) {
        final hasError = snapshot.hasError;

        return DrawerShell(
          icon: Icons.refresh,
          title: 'Recovering Funds...',
          children: [
            if (hasError)
              _buildErrorContent(snapshot.error.toString())
            else
              _buildRecoveringContent(),
          ],
        );
      },
    );
  }

  Widget _buildRecoveringContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 24),
        Text(
          'Keep this drawer open to progress the recovery.\nThis may take a few minutes.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildErrorContent(String error) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error, size: 64, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 24),
        Text(
          'Recovery failed',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          error,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
