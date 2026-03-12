import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:conduit/utils/notification_utils.dart';

class QrScannerWidget extends StatefulWidget {
  final void Function(String input) onScan;

  const QrScannerWidget({super.key, required this.onScan});

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  onPressed: _handleClipboardPaste,
                  icon: const Icon(Icons.paste, color: Colors.white, size: 36),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
