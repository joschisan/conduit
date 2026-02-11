import 'package:flutter/material.dart';
import 'package:conduit/widgets/qr_code_widget.dart';

// Pure UI composition
Widget _buildLnurlContent(BuildContext context, String lnurl) => Column(
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    Expanded(
      child: Center(
        child: Icon(
          Icons.bolt,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    ),
    QrCodeWidget(data: lnurl),
    Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Text(
            'This is a reusable payment code. You can use it to connect a point of sale that is compatible with Lightning Url Verify.',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  ],
);

class DisplayLnurlScreen extends StatelessWidget {
  final String lnurl;

  const DisplayLnurlScreen({super.key, required this.lnurl});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lightning Url')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox.expand(child: _buildLnurlContent(context, lnurl)),
      ),
    ),
  );
}
