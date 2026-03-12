import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';

class QrDisplayLayout extends StatelessWidget {
  final Widget header;
  final Widget qrCode;
  final String description;

  const QrDisplayLayout({
    super.key,
    required this.header,
    required this.qrCode,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: Center(child: header)),
        qrCode,
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                description,
                style: smallStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
