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
    final firstIsList = children.isNotEmpty && _isList(children.first);
    final lastIsList = children.isNotEmpty && _isList(children.last);
    final topPadding = firstIsList ? 0.0 : 16.0;
    final bottomPadding = lastIsList ? 0.0 : 16.0;

    // Flex children pass through uninset so they keep working inside the
    // column — a Flexible under a Padding is a ParentDataWidget error, which
    // blanks the whole sheet; they manage their own horizontal padding.
    bool passesThrough(Widget child) =>
        child is BorderedList || child is Flexible;

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
              passesThrough(child) ? child : _inset(child),
          ],
        ),
      ),
    );
  }

  /// Whether [child] is a list for spacing purposes, looking through the
  /// wrappers a list picks up on the way in: a [Flexible] holding a scroll
  /// view is still a list flush against the sheet edge, and adding the shell's
  /// 16px there would double the gap its rows already carry.
  static bool _isList(Widget child) {
    if (child is Flexible) return _isList(child.child);

    if (child is SingleChildScrollView) {
      final scrolled = child.child;

      return scrolled != null && _isList(scrolled);
    }

    return child is BorderedList;
  }

  static Widget _inset(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: child,
  );
}
