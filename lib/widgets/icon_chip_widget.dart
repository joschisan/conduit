import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';

/// A rounded square holding an [icon], used as the leading element of list rows
/// and drawer headers. The icon takes [color] (defaults to primary) over a 10%
/// tint of that same color, and the square sizes itself around the icon.
class IconChip extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double iconSize;

  const IconChip({
    super.key,
    required this.icon,
    this.color,
    this.iconSize = mediumIconSize,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? Theme.of(context).colorScheme.primary;
    final background = foreground.withValues(alpha: 0.1);

    return Container(
      padding: EdgeInsets.all(iconSize * 0.25),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(iconSize * 0.28),
      ),
      child: Icon(icon, size: iconSize, color: foreground),
    );
  }
}
