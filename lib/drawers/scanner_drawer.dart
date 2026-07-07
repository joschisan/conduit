import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/bridge_generated.dart/fountain.dart';
import 'package:conduit/bridge_generated.dart/lnurl.dart';
import 'package:conduit/widgets/qr_scanner_widget.dart';
import 'package:conduit/widgets/scanner_overlay_widget.dart';
import 'package:conduit/drawers/lightning_send_drawer.dart';
import 'package:conduit/drawers/ecash_drawer.dart';
import 'package:conduit/drawers/lnurl_drawer.dart';
import 'package:conduit/drawers/invite_drawer.dart';
import 'package:conduit/screens/onchain_amount_screen.dart';

class ScannerDrawer extends StatefulWidget {
  final ConduitClient client;
  final ConduitClientFactory clientFactory;
  final Future<void> Function(InviteCodeWrapper) onJoin;
  final Future<void> Function(InviteCodeWrapper) onRecover;
  // The home screen's balance unit, forwarded to any amount entry a scan opens.
  final bool fiat;

  const ScannerDrawer({
    super.key,
    required this.client,
    required this.clientFactory,
    required this.onJoin,
    required this.onRecover,
    this.fiat = false,
  });

  static Future<void> show(
    BuildContext context, {
    required ConduitClient client,
    required ConduitClientFactory clientFactory,
    required Future<void> Function(InviteCodeWrapper) onJoin,
    required Future<void> Function(InviteCodeWrapper) onRecover,
    bool fiat = false,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (_) => ScannerDrawer(
              client: client,
              clientFactory: clientFactory,
              onJoin: onJoin,
              onRecover: onRecover,
              fiat: fiat,
            ),
      ),
    );
  }

  @override
  State<ScannerDrawer> createState() => _ScannerDrawerState();
}

class _ScannerDrawerState extends State<ScannerDrawer> {
  final _decoder = ECashDecoder();
  bool _isScanning = true;

  void _processInput(String input) {
    if (!_isScanning) return;

    // Try each parser in order - first match wins
    final parsers = [
      (
        parseInviteCode(invite: input),
        (dynamic result) => InviteDrawer.show(
          context,
          invite: result,
          onJoin: widget.onJoin,
          onRecover: widget.onRecover,
        ),
      ),
      (
        parseBolt11Invoice(invoice: input),
        (dynamic result) => LightningSendDrawer.show(
          context,
          client: widget.client,
          invoice: result,
        ),
      ),
      (
        parseEcash(notes: input),
        (dynamic result) =>
            EcashDrawer.show(context, client: widget.client, notes: result),
      ),
      (
        parseBitcoinAddress(address: input),
        (dynamic result) => Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) => OnchainAmountScreen(
                  client: widget.client,
                  address: result,
                  fiat: widget.fiat,
                ),
          ),
        ),
      ),
      (
        parseLnurl(request: input),
        (dynamic result) => LnurlDrawer.show(
          context,
          client: widget.client,
          clientFactory: widget.clientFactory,
          lnurl: result,
          fiat: widget.fiat,
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
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop();
        showDrawer(result);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Let the camera bleed behind a transparent app bar, which still carries
      // the fullscreen-dialog Close (✕) over the preview.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          QrScannerWidget(onScan: _processInput, fill: true),
          const IgnorePointer(child: ScannerOverlay()),
        ],
      ),
    );
  }
}
