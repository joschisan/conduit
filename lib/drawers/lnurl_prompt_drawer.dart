import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/bridge_generated.dart/lnurl.dart';
import 'package:conduit/widgets/drawer_shell.dart';
import 'package:conduit/widgets/async_action_button.dart';
import 'package:conduit/screens/lnurl_payment_amount_screen.dart';
import 'package:conduit/drawers/lightning_payment_drawer.dart';
import 'package:conduit/utils/drawer_utils.dart';

class LnurlPromptDrawer extends StatelessWidget {
  final ConduitClient client;
  final ConduitClientFactory clientFactory;
  final LnurlWrapper lnurl;

  const LnurlPromptDrawer({
    super.key,
    required this.client,
    required this.clientFactory,
    required this.lnurl,
  });

  static Future<void> show(
    BuildContext context, {
    required ConduitClient client,
    required ConduitClientFactory clientFactory,
    required LnurlWrapper lnurl,
  }) {
    return DrawerUtils.show(
      context: context,
      child: LnurlPromptDrawer(
        client: client,
        clientFactory: clientFactory,
        lnurl: lnurl,
      ),
    );
  }

  Future<void> _handleContinue(BuildContext context) async {
    // Fetch limits from LNURL endpoint
    final payInfo = await lnurlFetchLimits(lnurl: lnurl);

    if (!context.mounted) return;

    // Check if fixed amount (MoneyBadger case: min == max)
    if (payInfo.minSats == payInfo.maxSats) {
      // Fixed amount - resolve invoice immediately
      final invoice = await lnurlResolve(
        payInfo: payInfo,
        amountSats: payInfo.minSats,
      );

      if (!context.mounted) return;

      Navigator.of(context).pop(); // Close this drawer
      LightningPaymentDrawer.show(context, client: client, invoice: invoice);
    } else {
      // Variable amount - show amount screen with payInfo
      final contactName = await clientFactory.getContactName(lnurl: lnurl);

      DrawerUtils.popAndPush(
        context,
        LnurlPaymentAmountScreen(
          client: client,
          clientFactory: clientFactory,
          lnurl: lnurl,
          payInfo: payInfo,
          contactName: contactName,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DrawerShell(
      icon: Icons.bolt,
      title: 'Detected Lightning Url',
      children: [
        const SizedBox(height: 8),
        AsyncActionButton(
          text: 'Continue',
          onPressed: () => _handleContinue(context),
        ),
      ],
    );
  }
}
