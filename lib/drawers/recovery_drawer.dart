import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/widgets/drawer_shell_widget.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/icon_chip_widget.dart';
import 'package:conduit/utils/drawer_utils.dart';

/// Blocks on a mint's recovery when a module can't run until it is done:
/// waits for every account of the mint, then has the factory reopen them so
/// the module joins the registry. The home screen picks the reopened clients
/// up from the client stream; there is nothing to navigate to.
class RecoveryDrawer extends StatefulWidget {
  /// Every account of the recovering mint.
  final List<ConduitClient> clients;
  final ConduitClientFactory clientFactory;

  const RecoveryDrawer({
    super.key,
    required this.clients,
    required this.clientFactory,
  });

  static Future<void> show(
    BuildContext context, {
    required List<ConduitClient> clients,
    required ConduitClientFactory clientFactory,
  }) {
    return DrawerUtils.show(
      context: context,
      child: RecoveryDrawer(clients: clients, clientFactory: clientFactory),
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
    await Future.wait(widget.clients.map((c) => c.waitForAllRecoveries()));

    await widget.clientFactory.reload(
      federationId: widget.clients.first.federationId(),
    );

    // Defer navigation until after the current frame completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
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
              smallSpinner,
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
