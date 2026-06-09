import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ellipsized_text/ellipsized_text.dart';
import 'package:conduit/utils/styles.dart';

/// A tappable row that displays shareable data (address, invoice, eCash token,
/// txid) middle-ellipsized in monospace over a [label] describing what it is,
/// sharing it on tap. Mirrors the detail rows so it sits naturally inside a
/// [BorderedList].
class ShareableRow extends StatelessWidget {
  final String data;
  final String label;

  const ShareableRow({super.key, required this.data, required this.label});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        SharePlus.instance.share(ShareParams(text: data));
      },
      contentPadding: listTilePadding,
      leading: Icon(
        PhosphorIconsRegular.copy,
        size: mediumIconSize,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EllipsizedText(
            data,
            type: EllipsisType.middle,
            style: mediumStyle.copyWith(fontFamily: 'monospace'),
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
