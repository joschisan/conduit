import 'package:flutter/widgets.dart';

/// Placeholder rendered in place of a monetary amount when the user has
/// toggled amounts off.
const maskedAmount = '•••••';

/// Broadcasts whether monetary amounts should be shown, letting descendants
/// (balances, payment tiles) mask them without prop-drilling. Defaults to
/// visible when no ancestor is present, so widgets reused outside the home
/// subtree (e.g. the payment-history screen) are unaffected.
class AmountVisibility extends InheritedWidget {
  final bool visible;

  const AmountVisibility({
    super.key,
    required this.visible,
    required super.child,
  });

  static bool of(BuildContext context) {
    final widget =
        context.dependOnInheritedWidgetOfExactType<AmountVisibility>();
    return widget?.visible ?? true;
  }

  @override
  bool updateShouldNotify(AmountVisibility oldWidget) =>
      visible != oldWidget.visible;
}
