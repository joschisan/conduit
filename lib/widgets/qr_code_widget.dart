import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:share_plus/share_plus.dart';

class QrCodeWidget extends StatelessWidget {
  final String data;
  final String? copyData;

  const QrCodeWidget({super.key, required this.data, this.copyData});

  void _handleTap() {
    SharePlus.instance.share(ShareParams(text: copyData ?? data));
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: _handleTap,
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
