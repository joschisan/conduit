import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:overlay_support/overlay_support.dart';

class NotificationUtils {
  static void _showNotification(
    BuildContext context,
    String message,
    IconData icon,
    Color textColor,
    Duration duration,
  ) {
    showOverlayNotification(
      (overlayContext) => SafeArea(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Icon(icon, color: textColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      duration: duration,
      position: NotificationPosition.top,
    );
  }

  static void showSuccess(BuildContext context, String message) {
    _showNotification(
      context,
      message,
      Icons.check_circle,
      Colors.green.shade200,
      const Duration(seconds: 3),
    );
  }

  static void showError(BuildContext context, String message) {
    _showNotification(
      context,
      message,
      Icons.error,
      Colors.red.shade200,
      const Duration(seconds: 3),
    );
  }

  static void showCopy(BuildContext context, String message) {
    _showNotification(
      context,
      message,
      Icons.copy,
      Theme.of(context).colorScheme.primary,
      const Duration(seconds: 2),
    );
  }

  static void showReceive(
    BuildContext context,
    int amountSat,
    PaymentType paymentType,
  ) {
    HapticFeedback.heavyImpact();

    final icon = switch (paymentType) {
      PaymentType.lightning => Icons.bolt,
      PaymentType.bitcoin => Icons.currency_bitcoin,
      PaymentType.ecash => Icons.toll,
    };

    _showNotification(
      context,
      'You received ${NumberFormat('#,###').format(amountSat)} sats.',
      icon,
      Theme.of(context).colorScheme.primary,
      const Duration(seconds: 3),
    );
  }

  static void showSend(
    BuildContext context,
    int amountSat,
    PaymentType paymentType,
  ) {
    HapticFeedback.heavyImpact();

    final icon = switch (paymentType) {
      PaymentType.lightning => Icons.bolt,
      PaymentType.bitcoin => Icons.currency_bitcoin,
      PaymentType.ecash => Icons.toll,
    };

    _showNotification(
      context,
      'You sent ${NumberFormat('#,###').format(amountSat)} sats.',
      icon,
      Theme.of(context).colorScheme.primary,
      const Duration(seconds: 3),
    );
  }
}
