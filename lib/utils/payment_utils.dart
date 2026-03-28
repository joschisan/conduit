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
}
