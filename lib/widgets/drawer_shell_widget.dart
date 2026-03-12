import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';

class DrawerShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const DrawerShell({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  icon,
                  size: largeIconSize,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(title, style: mediumStyle)),
              ],
            ),
            const SizedBox(height: 16),

            // Content
            ...children,
          ],
        ),
      ),
    );
  }
}
