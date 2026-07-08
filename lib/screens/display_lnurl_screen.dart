import 'package:balanced_text/balanced_text.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/widgets/qr_code_widget.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/bleed_column_widget.dart';
import 'package:conduit/widgets/shareable_row_widget.dart';
import 'package:conduit/widgets/async_icon_button_widget.dart';

class DisplayLnurlScreen extends StatelessWidget {
  final String lnurl;
  final String currencyCode;

  const DisplayLnurlScreen({
    super.key,
    required this.lnurl,
    required this.currencyCode,
  });

  /// Opens the kasse web point-of-sale, pre-loaded with this Lightning Url and
  /// currency so it lands directly on amount entry.
  Future<void> _openCheckout() async {
    final url = Uri.https('joschisan.github.io', '/kasse/', {
      'lnurl': lnurl,
      'currency': currencyCode,
    });
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Receive Lightning'),
      actions: [
        AsyncIconButton(
          icon: PhosphorIconsRegular.dotsNine,
          onPressed: _openCheckout,
        ),
      ],
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: BleedColumn(
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
                  child: BalancedText(
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
