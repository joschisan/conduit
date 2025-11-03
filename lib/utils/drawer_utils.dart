import 'package:flutter/material.dart';

void showStandardDrawer({
  required BuildContext context,
  required Widget child,
  Widget? topRightButton,
}) {
  showModalBottomSheet(
    context: context,
    isDismissible: true,
    enableDrag: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder:
        (context) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                child,
                if (topRightButton != null)
                  Positioned(top: 0, right: 0, child: topRightButton),
              ],
            ),
          ),
        ),
  );
}
