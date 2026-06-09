import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/widgets/qr_code_widget.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/shareable_row_widget.dart';

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
            BorderedList.column(
              children: [ShareableRow(data: lnurl, label: 'Lightning Url')],
            ),
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
