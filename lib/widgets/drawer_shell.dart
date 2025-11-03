import 'package:flutter/material.dart';
import 'package:conduit/widgets/icon_badge.dart';

class DrawerShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? topRightButton;
  final List<Widget> children;

  const DrawerShell({
    super.key,
    required this.icon,
    required this.title,
    this.topRightButton,
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
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    IconBadge(icon: icon, iconSize: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(title, style: const TextStyle(fontSize: 18)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Content
                ...children,
              ],
            ),

            // Top right button
            if (topRightButton != null)
              Positioned(top: 0, right: 0, child: topRightButton!),
          ],
        ),
      ),
    );
  }
}
