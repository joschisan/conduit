import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/widgets/drawer_shell.dart';
import 'package:conduit/widgets/icon_badge.dart';
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
      child: RecoveryDrawer(client: client, clientFactory: clientFactory),
    );
  }

  @override
  State<RecoveryDrawer> createState() => _RecoveryDrawerState();
}

class _RecoveryDrawerState extends State<RecoveryDrawer> {
  late final Future<void> _recoveryFuture;
  late final Stream<ConduitRecoveryProgress> _progressStream;

  @override
  void initState() {
    super.initState();
    _progressStream = widget.client.subscribeRecoveryProgress();
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

        return DrawerShell(
          icon: Icons.refresh,
          title: 'Recovering funds...',
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
    return StreamBuilder<ConduitRecoveryProgress>(
      stream: _progressStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          );
        }

        final progress =
            snapshot.data!.complete == snapshot.data!.total
                ? 1.0
                : snapshot.data!.complete / snapshot.data!.total;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Module ID ${snapshot.data!.moduleId}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      color: Theme.of(context).colorScheme.primary,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Keep this drawer open to progress the recovery.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        );
      },
    );
  }

  Widget _buildErrorContent(String error) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconBadge(
          icon: Icons.error_outline,
          iconSize: 48,
          color: Theme.of(context).colorScheme.error,
        ),
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
