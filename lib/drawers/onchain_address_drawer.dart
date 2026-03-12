import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/widgets/drawer_shell_widget.dart';
import 'package:conduit/widgets/async_button_widget.dart';
import 'package:conduit/screens/onchain_amount_screen.dart';
import 'package:conduit/utils/drawer_utils.dart';

class OnchainAddressDrawer extends StatelessWidget {
  final ConduitClient client;
  final BitcoinAddressWrapper address;

  const OnchainAddressDrawer({
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
      child: OnchainAddressDrawer(client: client, address: address),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DrawerShell(
      icon: Icons.currency_bitcoin,
      title: 'Onchain Address',
      children: [
        const SizedBox(height: 8),
        AsyncButton(
          text: 'Continue',
          onPressed:
              () async => DrawerUtils.popAndPush(
                context,
                OnchainAmountScreen(client: client, address: address),
              ),
        ),
      ],
    );
  }
}
