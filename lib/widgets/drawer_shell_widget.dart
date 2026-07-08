import 'package:flutter/material.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/utils/styles.dart';

/// Bottom-sheet scaffold. Lists run full-bleed to the sheet edges: a
/// [BorderedList] child gets no horizontal inset, while every other child
/// (headers, buttons, text) keeps the standard 16px side padding.
class DrawerShell extends StatelessWidget {
  final List<Widget> children;

  const DrawerShell({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    // A leading header or trailing button needs the full 16px gap. A list row
    // already carries 16px above/below its chip (8px content padding + 8px from
    // the chip centring within the taller two-line tile), so when a list sits
    // flush against a sheet edge the shell adds nothing there — otherwise the
    // chip ends up with more space above/below it than to its sides.
    final firstIsList = children.isNotEmpty && children.first is BorderedList;
    final lastIsList = children.isNotEmpty && children.last is BorderedList;
    final topPadding = firstIsList ? 0.0 : 16.0;
    final bottomPadding = lastIsList ? 0.0 : 16.0;

    return Container(
      padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: cornerRadiusValue),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final child in children)
              child is BorderedList ? child : _inset(child),
          ],
        ),
      ),
    );
  }

  static Widget _inset(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: child,
  );
}
