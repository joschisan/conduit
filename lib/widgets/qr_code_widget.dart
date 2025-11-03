import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:conduit/utils/notification_utils.dart';

class QrCodeWidget extends StatelessWidget {
  final String data;
  final String? copyData;

  const QrCodeWidget({super.key, required this.data, this.copyData});

  void _handleTap(BuildContext context) {
    Clipboard.setData(ClipboardData(text: copyData ?? data));
    NotificationUtils.showCopy(context, copyData ?? data);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => _handleTap(context),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: PrettyQrView.data(
        data: data.toUpperCase(),
        decoration: const PrettyQrDecoration(
          shape: PrettyQrSmoothSymbol(color: Colors.black),
          background: Colors.white,
        ),
      ),
    ),
  );
}
