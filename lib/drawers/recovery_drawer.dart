import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/widgets/drawer_shell_widget.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/icon_chip_widget.dart';
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
    await widget.client.shutdown();

    final newClient = await widget.clientFactory.load(
      federationId: widget.client.federationId(),
    );

    // Defer navigation until after the current frame completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Navigator.of(context).pop(); // Close drawer

      Navigator.of(context).push(
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
  void dispose() {
    widget.client.shutdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _recoveryFuture,
      builder: (context, snapshot) {
        return DrawerShell(
          children: [
            BorderedList.column(
              children: [
                if (snapshot.hasError)
                  _buildErrorRow(snapshot.error.toString())
                else
                  _buildRecoveringRow(),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecoveringRow() {
    final subColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return ListTile(
      contentPadding: listTilePadding,
      leading: const IconChip(icon: PhosphorIconsRegular.arrowsClockwise),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Recovering Funds', style: mediumStyle),
              const SizedBox(width: 8),
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
          Text(
            'Keep this drawer open',
            style: smallStyle.copyWith(color: subColor),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorRow(String error) {
    final subColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return ListTile(
      contentPadding: listTilePadding,
      leading: IconChip(
        icon: PhosphorIconsRegular.warningCircle,
        color: Theme.of(context).colorScheme.error,
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recovery Failed', style: mediumStyle),
          Text(error, style: smallStyle.copyWith(color: subColor)),
        ],
      ),
    );
  }
}
