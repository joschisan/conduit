import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/widgets/drawer_shell.dart';
import 'package:conduit/widgets/async_action_button.dart';
import 'package:conduit/screens/lnurl_payment_amount_screen.dart';
import 'package:conduit/drawers/lightning_payment_drawer.dart';
import 'package:conduit/utils/drawer_utils.dart';

class LnurlPromptDrawer extends StatelessWidget {
  final ConduitClient client;
  final LnurlWrapper lnurl;

  const LnurlPromptDrawer({
    super.key,
    required this.client,
    required this.lnurl,
  });

  static Future<void> show(
    BuildContext context, {
    required ConduitClient client,
    required LnurlWrapper lnurl,
  }) {
    return DrawerUtils.show(
      context: context,
      child: LnurlPromptDrawer(client: client, lnurl: lnurl),
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
      DrawerUtils.popAndPush(
        context,
        LnurlPaymentAmountScreen(
          client: client,
          payInfo: payInfo,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DrawerShell(
      icon: Icons.bolt,
      title: 'Detected Lightning URL',
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
