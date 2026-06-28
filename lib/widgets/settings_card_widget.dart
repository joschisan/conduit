import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/widgets/icon_chip_widget.dart';

class SettingsCard extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const SettingsCard({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;

    return ListTile(
      contentPadding: listTilePadding,
      leading: IconChip(icon: icon, color: iconColor),
      // Stack title/subtitle in the title (not subtitle) to keep the single-
      // line tile height instead of growing into Material's two-line layout.
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: mediumStyle),
          if (subtitle != null)
            Text(
              subtitle,
              style: smallStyle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
