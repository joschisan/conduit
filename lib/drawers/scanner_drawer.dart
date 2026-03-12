import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/bridge_generated.dart/fountain.dart';
import 'package:conduit/bridge_generated.dart/lnurl.dart';
import 'package:conduit/utils/drawer_utils.dart';
import 'package:conduit/widgets/qr_scanner_widget.dart';
import 'package:conduit/drawers/lightning_invoice_drawer.dart';
import 'package:conduit/drawers/ecash_drawer.dart';
import 'package:conduit/drawers/lnurl_drawer.dart';
import 'package:conduit/drawers/onchain_address_drawer.dart';

class ScannerDrawer extends StatefulWidget {
  final ConduitClient client;
  final ConduitClientFactory clientFactory;

  const ScannerDrawer({
    super.key,
    required this.client,
    required this.clientFactory,
  });

  static Future<void> show(
    BuildContext context, {
    required ConduitClient client,
    required ConduitClientFactory clientFactory,
  }) {
    return DrawerUtils.show(
      context: context,
      child: ScannerDrawer(client: client, clientFactory: clientFactory),
    );
  }

  @override
  State<ScannerDrawer> createState() => _ScannerDrawerState();
}

class _ScannerDrawerState extends State<ScannerDrawer> {
  final _decoder = OobNotesDecoder();
  bool _isScanning = true;

  void _processInput(String input) {
    if (!_isScanning) return;

    // Try each parser in order - first match wins
    final parsers = [
      (
        parseBolt11Invoice(invoice: input),
        (dynamic result) => LightningInvoiceDrawer.show(
          context,
          client: widget.client,
          invoice: result,
        ),
      ),
      (
        parseOobNotes(notes: input),
        (dynamic result) =>
            EcashDrawer.show(context, client: widget.client, notes: result),
      ),
      (
        parseBitcoinAddress(address: input),
        (dynamic result) => OnchainAddressDrawer.show(
          context,
          client: widget.client,
          address: result,
        ),
      ),
      (
        parseLnurl(request: input),
        (dynamic result) => LnurlDrawer.show(
          context,
          client: widget.client,
          clientFactory: widget.clientFactory,
          lnurl: result,
        ),
      ),
      (
        _decoder.addFragment(fragment: input),
        (dynamic result) =>
            EcashDrawer.show(context, client: widget.client, notes: result),
      ),
    ];

    for (final (result, showDrawer) in parsers) {
      if (result != null) {
        _isScanning = false;
        Navigator.of(context).pop();
        showDrawer(result);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return QrScannerWidget(onScan: _processInput);
  }
}
