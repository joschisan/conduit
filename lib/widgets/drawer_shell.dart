import 'package:flutter/material.dart';
import 'package:conduit/widgets/icon_badge.dart';

class DrawerShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? topRightButton;
  final List<Widget> children;
  final bool showSpinner;
  final Color? iconColor;

  const DrawerShell({
    super.key,
    required this.icon,
    required this.title,
    this.topRightButton,
    required this.children,
    this.showSpinner = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = IconBadge(icon: icon, iconSize: 32, color: iconColor);

    if (showSpinner) {
      iconWidget = Stack(
        alignment: Alignment.center,
        children: [
          iconWidget,
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      );
    }

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
                    iconWidget,
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
