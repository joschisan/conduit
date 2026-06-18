import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/utils/currency_utils.dart';
import 'package:conduit/widgets/animated_entry_widget.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/detail_row_widget.dart';

/// Shows the wallet balance as a "Balance in Bitcoin" row plus a "Balance in
/// `<currency>`" row, animating the value between balance updates.
///
/// The exchange rate is fetched once on load so the fiat row can appear; the
/// fiat figure is then converted from the cache and animates alongside the sat
/// amount.
class AnimatedBalanceDisplay extends StatefulWidget {
  final ConduitClient client;
  final int amount;

  const AnimatedBalanceDisplay(this.client, this.amount, {super.key});

  @override
  State<AnimatedBalanceDisplay> createState() => _AnimatedBalanceDisplayState();
}

class _AnimatedBalanceDisplayState extends State<AnimatedBalanceDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = AlwaysStoppedAnimation(widget.amount);

    // Warm the exchange rate cache so the fiat row can be shown, then rebuild.
    widget.client.prefetchExchangeRates().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(AnimatedBalanceDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amount != widget.amount) {
      _animation = IntTween(
        begin: _animation.value,
        end: widget.amount,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Widget> _balanceRows() {
    final amountSats = _animation.value;

    final rows = <Widget>[
      DetailRow(
        icon: PhosphorIconsRegular.currencyBtc,
        label: 'Balance in Bitcoin',
        value: '${NumberFormat('#,###').format(amountSats)} sat',
      ),
    ];

    final fiat = cachedFiatAmount(widget.client, amountSats);
    if (fiat != null) {
      rows.add(
        AnimatedEntry(
          child: DetailRow(
            icon: PhosphorIconsRegular.currencyDollar,
            label: 'Balance in ${fiat.currency}',
            value: fiat.amount,
          ),
        ),
      );
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder:
          (context, _) => BorderedList.column(children: _balanceRows()),
    );
  }
}
