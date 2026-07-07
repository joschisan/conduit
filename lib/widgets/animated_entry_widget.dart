import 'package:flutter/material.dart';

/// Grows its [child] in vertically on mount, used for newly appearing list
/// rows (recent payments, fetched fiat amounts). Set [animate] to false for
/// rows that were already present when their list appeared.
class AnimatedEntry extends StatefulWidget {
  final Widget child;
  final bool animate;
  const AnimatedEntry({super.key, required this.child, this.animate = true});

  @override
  State<AnimatedEntry> createState() => _AnimatedEntryState();
}

class _AnimatedEntryState extends State<AnimatedEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 500),
    value: widget.animate ? 0 : 1,
    vsync: this,
  )..forward();

  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(sizeFactor: _animation, child: widget.child);
  }
}
