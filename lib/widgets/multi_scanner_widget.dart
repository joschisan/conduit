import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:fpdart/fpdart.dart' hide State;
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/utils/notification_utils.dart';
import 'package:conduit/utils/drawer_utils.dart';
import 'package:conduit/widgets/async_action_button.dart';
import 'package:conduit/widgets/amount_display.dart';
import 'package:conduit/widgets/navigation_button.dart';
import 'package:conduit/screens/amount_screen.dart';

Widget _buildQrScanner(
  MobileScannerController controller,
  void Function(BarcodeCapture) onDetect,
) => LayoutBuilder(
  builder: (context, constraints) {
    final size = constraints.maxWidth;
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: MobileScanner(controller: controller, onDetect: onDetect),
      ),
    );
  },
);

Widget _buildPasteButton(VoidCallback? onPaste) => ElevatedButton.icon(
  onPressed: onPaste,
  icon: const Icon(Icons.paste, size: 24),
  label: const Text('Paste from Clipboard'),
  style: ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
);

class MultiScannerWidget extends StatefulWidget {
  final ConduitClient client;
  final TaskEither<String, void> Function(Bolt11InvoiceWrapper)
  onLightningPayment;
  final TaskEither<String, void> Function(OobNotesWrapper) onEcashRedeem;
  final TaskEither<String, void> Function(LnurlWrapper, int) onLnurlPayment;
  final TaskEither<String, void> Function(BitcoinAddressWrapper, int)
  onBitcoinWithdrawal;

  const MultiScannerWidget({
    super.key,
    required this.client,
    required this.onLightningPayment,
    required this.onEcashRedeem,
    required this.onLnurlPayment,
    required this.onBitcoinWithdrawal,
  });

  @override
  State<MultiScannerWidget> createState() => _MultiScannerWidgetState();
}

class _MultiScannerWidgetState extends State<MultiScannerWidget> {
  final _controller = MobileScannerController();
  final _decoder = OobNotesDecoder();
  bool _isScanning = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!mounted) return;
    if (!_isScanning) return;
    if (capture.barcodes.isEmpty) return;
    if (capture.barcodes.first.rawValue == null) return;

    _processInput(capture.barcodes.first.rawValue!);
  }

  void _processInput(String input) {
    final invoice = parseBolt11Invoice(invoice: input);

    if (invoice != null) {
      _isScanning = false;
      _showLightningDrawer(invoice);
      return;
    }

    final ecash = parseOobNotes(notes: input);

    if (ecash != null) {
      _isScanning = false;
      _showEcashDrawer(ecash);
      return;
    }

    final bitcoinAddress = parseBitcoinAddress(address: input);

    if (bitcoinAddress != null) {
      _isScanning = false;
      _showBitcoinAddressDrawer(bitcoinAddress);
      return;
    }

    final lnurl = parseLnurl(request: input);

    if (lnurl != null) {
      _isScanning = false;
      _showLnurlDrawer(lnurl);
      return;
    }

    final decodedNotes = _decoder.addFragment(part_: input);

    if (decodedNotes != null) {
      _isScanning = false;
      _showEcashDrawer(decodedNotes);
      return;
    }
  }

  void _showLightningDrawer(Bolt11InvoiceWrapper invoice) {
    Navigator.of(context).pop();

    final amountSats = invoice.amountSats();

    showStandardDrawer(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                child: Icon(
                  Icons.bolt,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              const Text('Lightning Invoice', style: TextStyle(fontSize: 18)),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: AmountDisplay(amountSats),
          ),
          const SizedBox(height: 16),
          AsyncActionButton(
            text: 'Confirm Payment',
            onPressed: () => widget.onLightningPayment(invoice),
            onSuccess:
                () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
    );
  }

  void _showEcashDrawer(OobNotesWrapper ecash) {
    Navigator.of(context).pop();

    final amountSats = ecash.amountSats();

    showStandardDrawer(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                child: Icon(
                  Icons.toll,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              const Text('eCash', style: TextStyle(fontSize: 18)),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: AmountDisplay(amountSats),
          ),
          const SizedBox(height: 16),
          AsyncActionButton(
            text: 'Redeem Notes',
            onPressed: () => widget.onEcashRedeem(ecash),
            onSuccess:
                () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
    );
  }

  void _showLnurlDrawer(LnurlWrapper lnurl) {
    Navigator.of(context).pop();

    showStandardDrawer(
      context: context,
      child: Builder(
        builder:
            (drawerContext) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Theme.of(
                        drawerContext,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      child: Icon(
                        Icons.link,
                        color: Theme.of(drawerContext).colorScheme.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Detected Lightning URL',
                      style: TextStyle(fontSize: 18),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 24),
                NavigationButton(
                  text: 'Continue',
                  onPressed: () {
                    Navigator.of(drawerContext).pop();
                    Navigator.of(drawerContext).push(
                      MaterialPageRoute(
                        builder:
                            (_) => AmountScreen(
                              client: widget.client,
                              onAmountSubmitted:
                                  (amountSats, _, __) =>
                                      widget.onLnurlPayment(lnurl, amountSats),
                            ),
                      ),
                    );
                  },
                ),
              ],
            ),
      ),
    );
  }

  void _showBitcoinAddressDrawer(BitcoinAddressWrapper address) {
    Navigator.of(context).pop();

    showStandardDrawer(
      context: context,
      child: Builder(
        builder:
            (drawerContext) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Theme.of(
                        drawerContext,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      child: Icon(
                        Icons.currency_bitcoin,
                        color: Theme.of(drawerContext).colorScheme.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Bitcoin Address Detected',
                      style: TextStyle(fontSize: 18),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 24),
                NavigationButton(
                  text: 'Continue',
                  onPressed: () {
                    Navigator.of(drawerContext).pop();
                    Navigator.of(drawerContext).push(
                      MaterialPageRoute(
                        builder:
                            (_) => AmountScreen(
                              client: widget.client,
                              onAmountSubmitted:
                                  (amountSats, _, __) => widget
                                      .onBitcoinWithdrawal(address, amountSats),
                              bitcoinAddress: address,
                            ),
                      ),
                    );
                  },
                ),
              ],
            ),
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      NotificationUtils.showError(context, message);
    }
  }

  Future<void> _handleClipboardPaste() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);

      final text = clipboardData?.text;

      if (text != null && text.isNotEmpty) {
        _processInput(text);
      } else {
        _showError('Clipboard is empty');
      }
    } catch (e) {
      _showError('Clipboard access error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildQrScanner(_controller, _onDetect),
        const SizedBox(height: 16),
        _buildPasteButton(_handleClipboardPaste),
      ],
    );
  }
}
