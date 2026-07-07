import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/widgets/icon_chip_widget.dart';

/// A single labelled row for bordered detail lists: a leading icon with the
/// value stacked over its label. A null value renders "Loading" with a small
/// spinner in the value slot until the value arrives.
///
/// The value/label pair lives in the `title` slot (rather than using
/// `ListTile.subtitle`) so the tile keeps the single-line height of the other
/// bordered lists while still showing a header and subheader.
class DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Color? iconColor;

  const DetailRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: listTilePadding,
      leading: IconChip(icon: icon, color: iconColor),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (value case final value?)
            Text(value, style: mediumStyle)
          else
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Loading', style: mediumStyle),
                SizedBox(width: 8),
                smallSpinner,
              ],
            ),
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
