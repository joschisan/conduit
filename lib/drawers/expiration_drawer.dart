import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/screens/federation_screen.dart';
import 'package:conduit/widgets/drawer_shell_widget.dart';
import 'package:conduit/widgets/async_button_widget.dart';
import 'package:conduit/utils/drawer_utils.dart';

class ExpirationDrawer extends StatelessWidget {
  final ConduitClientFactory clientFactory;
  final int date;
  final InviteCodeWrapper? successor;

  const ExpirationDrawer({
    super.key,
    required this.clientFactory,
    required this.date,
    this.successor,
  });

  static Future<void> show(
    BuildContext context, {
    required ConduitClientFactory clientFactory,
    required int date,
    InviteCodeWrapper? successor,
  }) {
    return DrawerUtils.show(
      context: context,
      child: ExpirationDrawer(
        clientFactory: clientFactory,
        date: date,
        successor: successor,
      ),
    );
  }

  String _formatDate() {
    return DateFormat.yMMMMd().format(
      DateTime.fromMillisecondsSinceEpoch(date * 1000),
    );
  }

  Future<void> _joinSuccessor(BuildContext context) async {
    final client = await clientFactory.join(invite: successor!);

    if (!context.mounted) return;

    Navigator.of(context).pop();

    if (!context.mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder:
            (_) =>
                FederationScreen(client: client, clientFactory: clientFactory),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = _formatDate();

    return DrawerShell(
      icon: Icons.bedtime,
      title: 'Expiry on $formattedDate',
      children: [
        Text(
          'This federation will expire on $formattedDate, please migrate your funds before this date.',
          textAlign: TextAlign.center,
        ),

        if (successor != null) ...[
          const SizedBox(height: 16),
          AsyncButton(
            text: 'Join Successor Federation',
            onPressed: () => _joinSuccessor(context),
          ),
        ],
      ],
    );
  }
}
