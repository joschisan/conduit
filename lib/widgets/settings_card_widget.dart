import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';

class SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const SettingsCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: listTilePadding,
      leading: Icon(
        icon,
        size: mediumIconSize,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(title, style: mediumStyle),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
