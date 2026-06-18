import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Tweens between balance values when `sats` changes — smooth counter
/// animation instead of a jarring text swap. Style-agnostic so the
/// same widget works for the hero balance, federation row cards, etc.
class AnimatedBalance extends StatefulWidget {
  final int sats;
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
  // Hosting screens often mount this widget with a placeholder `sats: 0`
  // while the balance stream resolves. Snap on the first update so the
  // tween only kicks in for genuine balance changes after that.
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = AlwaysStoppedAnimation(widget.sats);
  }

  @override
  void didUpdateWidget(AnimatedBalance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sats != widget.sats) {
      if (!_initialised) {
        _initialised = true;
        _animation = AlwaysStoppedAnimation(widget.sats);
      } else {
        _animation = IntTween(
          begin: _animation.value,
          end: widget.sats,
        ).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
        );
        _controller.forward(from: 0);
      }
    }
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
