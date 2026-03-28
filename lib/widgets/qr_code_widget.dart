import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

class QrCodeWidget extends StatelessWidget {
  final String data;
  final String iconAsset;

  const QrCodeWidget({super.key, required this.data, required this.iconAsset});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
    ),
    child: PrettyQrView.data(
      key: ValueKey(data),
      data: data.toUpperCase(),
      decoration: PrettyQrDecoration(
        shape: const PrettyQrSquaresSymbol(color: Colors.black, rounding: 1),
        background: Colors.white,
        image: PrettyQrDecorationImage(
          image: AssetImage(iconAsset),
          clipper: const PrettyQrCircleClipper(),
        ),
      ),
    ),
  );
}
