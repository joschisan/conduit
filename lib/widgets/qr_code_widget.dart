import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

class QrCodeWidget extends StatelessWidget {
  final String data;

  const QrCodeWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
    ),
    child: PrettyQrView.data(
      data: data,
      decoration: const PrettyQrDecoration(
        shape: PrettyQrSmoothSymbol(color: Colors.black),
        background: Colors.white,
      ),
    ),
  );
}
