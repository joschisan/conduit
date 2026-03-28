import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:conduit/bridge_generated.dart/events.dart';
import 'package:conduit/utils/payment_utils.dart';
import 'package:conduit/utils/styles.dart';

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
    Widget iconWidget = Icon(icon, size: mediumIconSize, color: iconColor);

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
            color: Color.lerp(
              Theme.of(overlayContext).colorScheme.surface,
              iconColor,
              0.15,
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                iconWidget,
                const SizedBox(width: 16),
                Expanded(child: Text(message, style: mediumStyle)),
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
      PhosphorIconsRegular.warningCircle,
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
      'Received ${NumberFormat('#,###').format(amountSat)} sat',
      PaymentTypeUtils.getIcon(paymentType),
      Theme.of(context).colorScheme.primary,
      _defaultNotificationDuration,
    );
  }

  static void showSuccess(BuildContext context, String message) {
    _showNotification(
      context,
      message,
      PhosphorIconsRegular.checkCircle,
      Colors.green,
      _defaultNotificationDuration,
    );
  }
}
