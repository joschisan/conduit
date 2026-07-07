import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:conduit/utils/styles.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:conduit/utils/notification_utils.dart';

class QrScannerWidget extends StatefulWidget {
  final void Function(String input) onScan;
  // When true the camera fills its parent edge-to-edge (full-bleed, for a
  // full-screen scanner). When false it renders as the rounded square used
  // inside bottom sheets.
  final bool fill;

  const QrScannerWidget({super.key, required this.onScan, this.fill = false});

  @override
  State<QrScannerWidget> createState() => _QrScannerWidgetState();
}

class _QrScannerWidgetState extends State<QrScannerWidget> {
  final _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!mounted) return;
    if (capture.barcodes.isEmpty) return;
    if (capture.barcodes.first.rawValue == null) return;

    widget.onScan(capture.barcodes.first.rawValue!);
  }

  Future<void> _handleClipboardPaste() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text;

      if (text != null && text.isNotEmpty) {
        widget.onScan(text);
      } else {
        if (mounted) {
          NotificationUtils.showError(context, 'Failed to access clipboard');
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationUtils.showError(context, 'Failed to access clipboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Full-bleed preview only; the full-screen scanner supplies its own paste
    // control in the app bar, aligned with the Close button.
    if (widget.fill) {
      return MobileScanner(controller: _controller, onDetect: _onDetect);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: cornerRadius,
                child: MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: _handleClipboardPaste,
                  icon: const Icon(
                    PhosphorIconsRegular.clipboardText,
                    size: smallIconSize,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
