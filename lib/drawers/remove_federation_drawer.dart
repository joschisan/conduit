import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/widgets/drawer_shell_widget.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/settings_card_widget.dart';
import 'package:conduit/widgets/async_button_widget.dart';
import 'package:conduit/utils/auth_utils.dart';
import 'package:conduit/utils/drawer_utils.dart';

/// Confirmation sheet for removing the mint in view — every account of it at
/// once. The row names the mint under what is about to happen to it, as in
/// pico. The factory shuts the live client down before wiping its database,
/// then [onSuccess] runs for whatever the caller wants afterwards.
class RemoveFederationDrawer extends StatefulWidget {
  final ConduitClient client;
  final ConduitClientFactory clientFactory;
  final VoidCallback onSuccess;

  const RemoveFederationDrawer({
    super.key,
    required this.client,
    required this.clientFactory,
    required this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required ConduitClient client,
    required ConduitClientFactory clientFactory,
    required VoidCallback onSuccess,
  }) {
    return DrawerUtils.show(
      context: context,
      child: RemoveFederationDrawer(
        client: client,
        clientFactory: clientFactory,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<RemoveFederationDrawer> createState() => _RemoveFederationDrawerState();
}

class _RemoveFederationDrawerState extends State<RemoveFederationDrawer> {
  late final String _federationName = widget.client.federationName();

  Future<void> _handleRemoveFederation() async {
    // Gate the destructive wipe behind the same biometric check as the seed
    // phrase; a failed or cancelled auth throws and aborts before any teardown.
    await requireBiometricAuth(context);

    if (!mounted) return;

    await widget.clientFactory.leave(
      federationId: widget.client.federationId(),
    );

    if (!mounted) return;

    Navigator.of(context).pop();
    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    return DrawerShell(
      children: [
        BorderedList.column(
          children: [
            SettingsCard(
              icon: PhosphorIconsRegular.trash,
              title: 'Remove Mint',
              subtitle: _federationName,
            ),
          ],
        ),
        const SizedBox(height: 16),
        AsyncButton(text: 'Confirm', onPressed: _handleRemoveFederation),
      ],
    );
  }
}
