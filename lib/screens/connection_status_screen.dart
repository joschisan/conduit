import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/widgets/icon_chip_widget.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/bleed_column_widget.dart';
import 'package:conduit/widgets/section_header_widget.dart';
import 'package:conduit/widgets/connection_status_header_widget.dart';

class ConnectionStatusScreen extends StatefulWidget {
  final ConduitClient client;

  const ConnectionStatusScreen({super.key, required this.client});

  @override
  State<ConnectionStatusScreen> createState() => _ConnectionStatusScreenState();
}

class _ConnectionStatusScreenState extends State<ConnectionStatusScreen> {
  // Resolved once, above the status stream, so status updates don't re-trigger
  // the lookup.
  String _name = 'Mint';

  @override
  void initState() {
    super.initState();
    widget.client.federationName().then((name) {
      if (mounted && name != null) setState(() => _name = name);
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Connectivity')),
      body: StreamBuilder<List<(String, bool)>>(
        stream: widget.client.subscribeConnectionStatus(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: smallSpinner);
          }

          final statuses = snapshot.data!;
          final online = statuses.where((s) => s.$2).length;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
            child: BleedColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Mint'),
                BorderedList.column(
                  children: [
                    ConnectionStatusHeader(
                      name: _name,
                      online: online,
                      total: statuses.length,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const SectionHeader(title: 'Guardians'),
                BorderedList.column(
                  children: [
                    for (final (name, connected) in statuses)
                      ListTile(
                        contentPadding: listTilePadding,
                        leading: IconChip(
                          icon: PhosphorIconsRegular.hardDrives,
                          color: connected ? null : Colors.amber,
                        ),
                        // Stack name/status in the title (not subtitle) to keep the
                        // single-line tile height.
                        title: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(name, style: mediumStyle),
                            Text(
                              connected ? 'Online' : 'Offline',
                              style: smallStyle.copyWith(
                                color: connected ? color : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
