import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/events.dart';

class PaymentTypeUtils {
  PaymentTypeUtils._();

  static IconData getIcon(PaymentType type) {
    return switch (type) {
      PaymentType.lightning => PhosphorIconsRegular.lightning,
      PaymentType.bitcoin => PhosphorIconsRegular.link,
      PaymentType.ecash => PhosphorIconsRegular.coinVertical,
    };
  }

  /// Arrow encoding payment direction: incoming points down, outgoing up.
  static IconData getDirectionIcon(bool incoming) =>
      incoming ? PhosphorIconsRegular.arrowDown : PhosphorIconsRegular.arrowUp;

  static String getLabel(PaymentType type) {
    return switch (type) {
      PaymentType.lightning => 'Lightning',
      PaymentType.bitcoin => 'Onchain',
      PaymentType.ecash => 'eCash',
    };
  }

  /// Status label for a payment: tense follows progress, direction follows
  /// incoming (Sending/Receiving → Sent/Received, or Failed).
  static String getStatus({required bool incoming, required bool? success}) {
    return switch (success) {
      null => incoming ? 'Receiving' : 'Sending',
      true => incoming ? 'Received' : 'Sent',
      false => 'Failed',
    };
  }
}

/// Compact relative time for payment subheaders (Now / 5m / 2h / 3d).
String formatRelativeTime(DateTime dateTime) {
  final difference = DateTime.now().difference(dateTime);

  return switch (difference) {
    _ when difference.inMinutes < 1 => 'Now',
    _ when difference.inMinutes < 60 => '${difference.inMinutes}m',
    _ when difference.inHours < 24 => '${difference.inHours}h',
    _ => '${difference.inDays}d',
  };
}
