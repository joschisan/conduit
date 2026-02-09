import 'package:flutter/material.dart';

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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 8.0,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(
          icon,
          size: 32,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}
