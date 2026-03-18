import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';

class ConnectionStatusScreen extends StatelessWidget {
  final ConduitClient client;

  const ConnectionStatusScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<String?>(
          future: client.federationName(),
          builder: (context, snapshot) {
            return Text(snapshot.data ?? 'Federation');
          },
        ),
      ),
      body: StreamBuilder<List<(String, bool)>>(
        stream: client.subscribeConnectionStatus(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final statuses = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: BorderedList.column(
              children: [
                for (final (name, connected) in statuses)
                  ListTile(
                    contentPadding: listTilePadding,
                    leading: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: connected ? color : color.withValues(alpha: 0.3),
                      ),
                    ),
                    title: Text(name, style: mediumStyle),
                    trailing: Text(
                      connected ? 'Online' : 'Offline',
                      style: smallStyle.copyWith(
                        color: connected ? color : null,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
