import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/widgets/drawer_shell.dart';
import 'package:conduit/widgets/async_action_button.dart';
import 'package:conduit/screens/bitcoin_send_amount_screen.dart';
import 'package:conduit/utils/drawer_utils.dart';

class BitcoinAddressPromptDrawer extends StatelessWidget {
  final ConduitClient client;
  final BitcoinAddressWrapper address;

  const BitcoinAddressPromptDrawer({
    super.key,
    required this.client,
    required this.address,
  });

  static Future<void> show(
    BuildContext context, {
    required ConduitClient client,
    required BitcoinAddressWrapper address,
  }) {
    return DrawerUtils.show(
      context: context,
      child: BitcoinAddressPromptDrawer(client: client, address: address),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DrawerShell(
      icon: Icons.currency_bitcoin,
      title: 'Bitcoin Address Detected',
      children: [
        const SizedBox(height: 8),
        AsyncActionButton(
          text: 'Continue',
          onPressed:
              () async => DrawerUtils.popAndPush(
                context,
                BitcoinSendAmountScreen(client: client, address: address),
              ),
        ),
      ],
    );
  }
}
