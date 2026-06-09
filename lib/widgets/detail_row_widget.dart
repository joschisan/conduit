import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';

/// A single labelled row for bordered detail lists: a leading icon with the
/// value stacked over its label.
///
/// The value/label pair lives in the `title` slot (rather than using
/// `ListTile.subtitle`) so the tile keeps the single-line height of the other
/// bordered lists while still showing a header and subheader.
class DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const DetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
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
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: mediumStyle),
          Text(
            label,
            style: smallStyle.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
