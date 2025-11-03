import 'package:flutter/material.dart';

class IconBadge extends StatelessWidget {
  final IconData? icon;
  final Widget? child;
  final double iconSize;
  final Color? color;

  const IconBadge({
    super.key,
    this.icon,
    this.child,
    required this.iconSize,
    this.color,
  }) : assert(
         icon != null || child != null,
         'Either icon or child must be provided',
       );

  // Derive container size from icon (same ratio as existing badges)
  double get _containerSize => iconSize * 1.54;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    return Container(
      width: _containerSize,
      height: _containerSize,
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: effectiveColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: child ?? Icon(icon!, size: iconSize, color: effectiveColor),
    );
  }
}
