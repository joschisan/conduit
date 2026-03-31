import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/widgets/qr_code_widget.dart';
import 'package:conduit/widgets/shareable_data_widget.dart';

class DisplayLnurlScreen extends StatelessWidget {
  final String lnurl;

  const DisplayLnurlScreen({super.key, required this.lnurl});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Receive Lightning')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            QrCodeWidget(data: lnurl),
            const SizedBox(height: 16),
            ShareableData(data: lnurl),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'This is a reusable payment code.',
                    style: smallStyle.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
