import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/events.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/bridge_generated.dart/lnurl.dart';
import 'package:conduit/widgets/drawer_shell_widget.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/icon_chip_widget.dart';
import 'package:conduit/screens/lnurl_amount_screen.dart';
import 'package:conduit/drawers/lightning_invoice_drawer.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/utils/payment_utils.dart';
import 'package:conduit/utils/notification_utils.dart';
import 'package:conduit/utils/drawer_utils.dart';

class LnurlDrawer extends StatefulWidget {
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

  @override
  State<LnurlDrawer> createState() => _LnurlDrawerState();
}

class _LnurlDrawerState extends State<LnurlDrawer> {
  @override
  void initState() {
    super.initState();
    // Contact the lightning address immediately — the drawer is purely a
    // progress surface, so there is nothing for the user to confirm first.
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final payResponse = await lnurlFetchLimits(lnurl: widget.lnurl);

      if (!mounted) return;

      if (payResponse.isFixedAmount()) {
        final invoice = await lnurlResolve(
          payResponse: payResponse,
          amountSats: payResponse.minSats,
        );

        if (!mounted) return;

        Navigator.of(context).pop();
        LightningInvoiceDrawer.show(
          context,
          client: widget.client,
          invoice: invoice,
        );
      } else {
        final contactName = await widget.clientFactory.getContactName(
          lnurl: widget.lnurl,
        );

        if (!mounted) return;

        DrawerUtils.popAndPush(
          context,
          LnurlAmountScreen(
            client: widget.client,
            clientFactory: widget.clientFactory,
            lnurl: widget.lnurl,
            payResponse: payResponse,
            contactName: contactName,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;

      // Close the drawer and surface the failure as the standard error overlay,
      // matching the old confirm button.
      Navigator.of(context).pop();
      NotificationUtils.showError(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return DrawerShell(
      children: [
        BorderedList.column(children: [_buildFetchingRow()]),
      ],
    );
  }

  Widget _buildFetchingRow() {
    final subColor = Theme.of(context).colorScheme.onSurfaceVariant;

    // The lnurl payload is the decoded service URL, so its host is the provider
    // domain (e.g. blink.sv), shown as the subheader like the contacts list.
    final domain = Uri.tryParse(widget.lnurl.field0)?.host;

    return ListTile(
      contentPadding: listTilePadding,
      leading: IconChip(icon: PaymentTypeUtils.getDirectionIcon(false)),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                PaymentTypeUtils.getLabel(PaymentType.lightning),
                style: mediumStyle,
              ),
              const SizedBox(width: 8),
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
          if (domain != null && domain.isNotEmpty)
            Text(domain, style: smallStyle.copyWith(color: subColor)),
        ],
      ),
    );
  }
}
