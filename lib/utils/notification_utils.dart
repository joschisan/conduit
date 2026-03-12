import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:conduit/bridge_generated.dart/events.dart';
import 'package:conduit/utils/payment_type_utils.dart';

class NotificationUtils {
  static const _defaultNotificationDuration = Duration(milliseconds: 1500);

  static OverlaySupportEntry _showNotification(
    BuildContext context,
    String message,
    IconData icon,
    Color iconColor,
    Duration duration, {
    bool showSpinner = false,
  }) {
    Widget iconWidget = Icon(icon, size: 26, color: iconColor);

    if (showSpinner) {
      iconWidget = Stack(
        alignment: Alignment.center,
        children: [
          iconWidget,
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      );
    }

    return showOverlayNotification(
      (overlayContext) => Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(overlayContext).colorScheme.surfaceContainer,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                iconWidget,
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(overlayContext).colorScheme.onSurface,
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

  static void showError(BuildContext context, String message) {
    _showNotification(
      context,
      message,
      Icons.error,
      Colors.red,
      _defaultNotificationDuration,
    );
  }

  static void showReceive(
    BuildContext context,
    int amountSat,
    PaymentType paymentType,
  ) {
    HapticFeedback.heavyImpact();

    _showNotification(
      context,
      'You received ${NumberFormat('#,###').format(amountSat)} sats.',
      PaymentTypeUtils.getIcon(paymentType),
      Theme.of(context).colorScheme.primary,
      _defaultNotificationDuration,
    );
  }

  static void showSend(
    BuildContext context,
    int amountSat,
    PaymentType paymentType,
  ) {
    HapticFeedback.heavyImpact();

    _showNotification(
      context,
      'You sent ${NumberFormat('#,###').format(amountSat)} sats.',
      PaymentTypeUtils.getIcon(paymentType),
      Theme.of(context).colorScheme.primary,
      _defaultNotificationDuration,
    );
  }

  static void showCopy(BuildContext context, String message) {
    _showNotification(
      context,
      message.length > 20 ? '${message.substring(0, 20)}...' : message,
      Icons.copy,
      Theme.of(context).colorScheme.primary,
      _defaultNotificationDuration,
    );
  }
}
