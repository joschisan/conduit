import 'package:flutter/widgets.dart';

/// Placeholder rendered in place of a monetary amount when the user has
/// toggled amounts off.
const maskedAmount = '•••••';

/// How a monetary amount renders, cycled by the app-bar controls.
enum BalanceDisplay { sats, fiat, hidden }

/// Broadcasts how monetary amounts should render (sats / fiat / hidden), letting
/// descendants (balances, payment tiles) adapt without prop-drilling. Defaults
/// to sats when no ancestor is present, so widgets reused outside a providing
/// subtree are unaffected.
class AmountDisplay extends InheritedWidget {
  final BalanceDisplay display;

  const AmountDisplay({super.key, required this.display, required super.child});

  static BalanceDisplay of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<AmountDisplay>();
    return widget?.display ?? BalanceDisplay.sats;
  }

  @override
  bool updateShouldNotify(AmountDisplay oldWidget) =>
      display != oldWidget.display;
}
