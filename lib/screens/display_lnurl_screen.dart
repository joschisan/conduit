import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/widgets/qr_code_widget.dart';
import 'package:conduit/widgets/qr_display_layout_widget.dart';

class DisplayLnurlScreen extends StatelessWidget {
  final String lnurl;

  const DisplayLnurlScreen({super.key, required this.lnurl});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lightning Url')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: QrDisplayLayout(
          header: Icon(
            Icons.bolt,
            size: heroIconSize,
            color: Theme.of(context).colorScheme.primary,
          ),
          qrCode: QrCodeWidget(data: lnurl),
          description:
              'This is a reusable payment code. It supports payment verification and can be used with a compatible point of sale.',
        ),
      ),
    ),
  );
}
