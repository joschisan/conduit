import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/bridge_generated.dart/lnurl.dart';
import 'package:conduit/widgets/amount_entry_widget.dart';
import 'package:conduit/drawers/contact_drawer.dart';
import 'package:conduit/utils/auth_utils.dart';

class LnurlPaymentAmountScreen extends StatefulWidget {
  final ConduitClient client;
  final ConduitClientFactory clientFactory;
  final LnurlWrapper lnurl;
  final LnurlPayInfo payInfo;
  final String? contactName;

  const LnurlPaymentAmountScreen({
    super.key,
    required this.client,
    required this.clientFactory,
    required this.lnurl,
    required this.payInfo,
    this.contactName,
  });

  @override
  State<LnurlPaymentAmountScreen> createState() =>
      _LnurlPaymentAmountScreenState();
}

class _LnurlPaymentAmountScreenState extends State<LnurlPaymentAmountScreen> {
  late String? _contactName = widget.contactName;

  Future<void> _handleConfirm(int amountSats) async {
    final invoice = await lnurlResolve(
      payInfo: widget.payInfo,
      amountSats: amountSats,
    );

    if (!mounted) return;

    await requireBiometricAuth(context);

    await widget.client.lnSend(invoice: invoice);

    if (!mounted) return;

    Navigator.of(context).pop();
  }

  Future<void> _handleSaveContact() async {
    final name = await ContactDrawer.show(
      context,
      clientFactory: widget.clientFactory,
      lnurl: widget.lnurl,
    );

    if (mounted && name != null) {
      setState(() => _contactName = name);
    }
  }

  void _handleShare() {
    SharePlus.instance.share(ShareParams(text: widget.lnurl.encode()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(_contactName ?? 'Lightning Url'),
        actions: [
          if (_contactName == null)
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: _handleSaveContact,
            )
          else
            IconButton(icon: const Icon(Icons.share), onPressed: _handleShare),
        ],
      ),
      body: SafeArea(
        maintainBottomViewPadding: true,
        child: AmountEntryWidget(
          client: widget.client,
          onConfirm: _handleConfirm,
        ),
      ),
    );
  }
}
