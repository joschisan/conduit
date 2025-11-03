import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/events.dart';

class PaymentTypeUtils {
  PaymentTypeUtils._();

  static IconData getIcon(PaymentType type) {
    return switch (type) {
      PaymentType.lightning => Icons.bolt,
      PaymentType.bitcoin => Icons.currency_bitcoin,
      PaymentType.ecash => Icons.toll,
    };
  }

  static String getDisplayName(PaymentType type) {
    return switch (type) {
      PaymentType.lightning => 'Lightning',
      PaymentType.bitcoin => 'Bitcoin',
      PaymentType.ecash => 'eCash',
    };
  }
}
