import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:conduit/utils/notification_utils.dart';

class CopyButton extends StatelessWidget {
  final String data;
  final String message;

  const CopyButton({super.key, required this.data, required this.message});

  void _handleCopy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: data));
    NotificationUtils.showCopy(context, message);
  }

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    onPressed: () => _handleCopy(context),
    icon: const Icon(Icons.copy, size: 24),
    label: const Text('Copy to Clipboard'),
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}
