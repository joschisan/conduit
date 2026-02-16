import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/bridge_generated.dart/lnurl.dart';
import 'package:conduit/widgets/drawer_shell_widget.dart';
import 'package:conduit/widgets/async_button_widget.dart';
import 'package:conduit/screens/lnurl_amount_screen.dart';
import 'package:conduit/drawers/lightning_invoice_drawer.dart';
import 'package:conduit/utils/drawer_utils.dart';

class LnurlDrawer extends StatelessWidget {
  final ConduitClient client;
  final ConduitClientFactory clientFactory;
  final LnurlWrapper lnurl;

  const LnurlDrawer({
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
      child: LnurlDrawer(
        client: client,
        clientFactory: clientFactory,
        lnurl: lnurl,
      ),
    );
  }

  Future<void> _handleContinue(BuildContext context) async {
    // Fetch limits from LNURL endpoint
    final payResponse = await lnurlFetchLimits(lnurl: lnurl);

    if (!context.mounted) return;

    // Check if fixed amount (MoneyBadger case: min == max)
    if (payResponse.minSats == payResponse.maxSats) {
      // Fixed amount - resolve invoice immediately
      final invoice = await lnurlResolve(
        payResponse: payResponse,
        amountSats: payResponse.minSats,
      );

      if (!context.mounted) return;

      Navigator.of(context).pop(); // Close this drawer
      LightningInvoiceDrawer.show(context, client: client, invoice: invoice);
    } else {
      // Variable amount - show amount screen with payResponse
      final contactName = await clientFactory.getContactName(lnurl: lnurl);

      if (!context.mounted) return;

      DrawerUtils.popAndPush(
        context,
        LnurlAmountScreen(
          client: client,
          clientFactory: clientFactory,
          lnurl: lnurl,
          payResponse: payResponse,
          contactName: contactName,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DrawerShell(
      icon: Icons.bolt,
      title: 'Lightning Url',
      children: [
        const SizedBox(height: 8),
        AsyncButton(
          text: 'Continue',
          onPressed: () => _handleContinue(context),
        ),
      ],
    );
  }
}
