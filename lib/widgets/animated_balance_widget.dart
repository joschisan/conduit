import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Tweens between balance values when `sats` changes — smooth counter
/// animation instead of a jarring text swap. Style-agnostic so the
/// same widget works for the hero balance, federation row cards, etc.
class AnimatedBalance extends StatefulWidget {
  // Null while the balance is still resolving (e.g. before the stream's first
  // value). Distinguishing this from a genuine 0 matters: an actual 0 balance
  // (during recovery, or an empty wallet) is a real value to snap to, so the
  // change away from it — 0 to recovered funds, or 0 to a first payment —
  // animates instead of being mistaken for the initial value.
  final int? sats;
  final TextStyle style;
  // When set, the " sat" suffix renders in this (typically smaller) style
  // while the number keeps `style` — matching the amount-entry display.
  final TextStyle? unitStyle;
  // When set, each tweened sats value is rendered through this instead of the
  // default "N sat" — e.g. converting to a fiat string so the fiat figure
  // counts up on the same tween as the sats amount.
  final String Function(int sats)? formatter;
  final TextAlign? textAlign;
  final Duration duration;

  const AnimatedBalance({
    super.key,
    required this.sats,
    required this.style,
    this.unitStyle,
    this.formatter,
    this.textAlign,
    this.duration = const Duration(milliseconds: 1000),
  });

  @override
  State<AnimatedBalance> createState() => _AnimatedBalanceState();
}

class _AnimatedBalanceState extends State<AnimatedBalance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<int> _animation;
  // Whether a resolved (non-null) balance has been seen yet. The first one is
  // snapped to; genuine changes after that tween.
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = AlwaysStoppedAnimation(widget.sats ?? 0);
    _initialised = widget.sats != null;
  }

  @override
  void didUpdateWidget(AnimatedBalance oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sats = widget.sats;
    // Still resolving, or an unrelated rebuild with the same value.
    if (sats == null || sats == oldWidget.sats) return;

    if (!_initialised) {
      // First resolved balance — snap to it, even when it is 0, so the change
      // away from it animates rather than being taken for the initial value.
      _initialised = true;
      _animation = AlwaysStoppedAnimation(sats);
      return;
    }

    _animation = IntTween(begin: _animation.value, end: sats).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, _) {
        if (widget.formatter != null) {
          return Text(
            widget.formatter!(_animation.value),
            style: widget.style,
            textAlign: widget.textAlign,
          );
        }
        final number = NumberFormat('#,###').format(_animation.value);
        if (widget.unitStyle == null) {
          return Text(
            '$number sat',
            style: widget.style,
            textAlign: widget.textAlign,
          );
        }
        return Text.rich(
          TextSpan(
            children: [
              TextSpan(text: number, style: widget.style),
              TextSpan(text: ' sat', style: widget.unitStyle),
            ],
          ),
          textAlign: widget.textAlign,
        );
      },
    );
  }
}
