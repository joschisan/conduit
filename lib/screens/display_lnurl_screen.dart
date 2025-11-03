import 'package:flutter/material.dart';
import 'package:conduit/widgets/qr_code_widget.dart';
import 'package:conduit/widgets/copy_button.dart';

// Pure UI composition
Widget _buildLnurlContent(BuildContext context, String lnurl) => Column(
  mainAxisAlignment: MainAxisAlignment.center,
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    QrCodeWidget(data: lnurl),
    const SizedBox(height: 16),
    CopyButton(data: lnurl, message: 'Lightning URL copied to clipboard'),
    const SizedBox(height: 24),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Text(
        'This is a reusable payment code. You can use it to connect a point of sale that is compatible with LNURL Verify.',
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
        ),
        textAlign: TextAlign.center,
      ),
    ),
  ],
);

class DisplayLnurlScreen extends StatelessWidget {
  final String lnurl;

  const DisplayLnurlScreen({super.key, required this.lnurl});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lightning URL')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox.expand(child: _buildLnurlContent(context, lnurl)),
      ),
    ),
  );
}
