import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:fpdart/fpdart.dart' hide State;
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/utils/notification_utils.dart';
import 'package:conduit/utils/drawer_utils.dart';
import 'package:conduit/widgets/async_action_button.dart';

Widget _buildQrScanner(
  MobileScannerController controller,
  void Function(BarcodeCapture) onDetect,
  VoidCallback? onPaste,
) => LayoutBuilder(
  builder: (context, constraints) {
    final size = constraints.maxWidth;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: MobileScanner(controller: controller, onDetect: onDetect),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              onPressed: onPaste,
              icon: const Icon(Icons.paste, color: Colors.white, size: 36),
            ),
          ),
        ],
      ),
    );
  },
);

class InviteScannerWidget extends StatefulWidget {
  final ConduitClientFactory clientFactory;
  final TaskEither<String, void> Function(InviteCodeWrapper) onJoin;
  final TaskEither<String, void> Function(InviteCodeWrapper) onRecover;

  const InviteScannerWidget({
    super.key,
    required this.clientFactory,
    required this.onJoin,
    required this.onRecover,
  });

  @override
  State<InviteScannerWidget> createState() => _InviteScannerWidgetState();
}

class _InviteScannerWidgetState extends State<InviteScannerWidget> {
  final _controller = MobileScannerController();
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

  void _processInput(String invite) {
    final inviteCode = parseInviteCode(invite: invite);

    if (inviteCode != null) {
      _isScanning = false;
      _showInviteDrawer(inviteCode);
      return;
    }
  }

  void _showInviteDrawer(InviteCodeWrapper invite) {
    Navigator.of(context).pop();

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
                  Icons.link,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              const Text('Invite Code', style: TextStyle(fontSize: 18)),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          AsyncActionButton(
            text: 'Recover',
            onPressed: () => widget.onRecover(invite),
          ),
          const SizedBox(height: 12),
          AsyncActionButton(
            text: 'Join',
            onPressed: () => widget.onJoin(invite),
          ),
        ],
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
    return _buildQrScanner(_controller, _onDetect, _handleClipboardPaste);
  }
}
