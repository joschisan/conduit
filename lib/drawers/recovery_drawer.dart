import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/widgets/drawer_shell.dart';
import 'package:conduit/utils/drawer_utils.dart';
import 'package:conduit/screens/home_screen.dart';

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
      child: RecoveryDrawer(
        client: client,
        clientFactory: clientFactory,
      ),
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

    // Defer navigation until after the current frame completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Navigator.of(context).pop(); // Close drawer

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (_) => HomeScreen(
                client: widget.client,
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
        final icon = hasError ? Icons.error_outline : Icons.refresh;
        final iconColor = hasError ? Colors.red : null;

        return DrawerShell(
          icon: icon,
          iconColor: iconColor,
          title: 'Recovery',
          showSpinner: !hasError,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        'Keep this drawer open to progress the recovery.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _buildErrorContent(String error) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
      ),
    );
  }
}
