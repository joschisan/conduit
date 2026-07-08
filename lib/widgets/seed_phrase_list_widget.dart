import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/utils/number_utils.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/icon_chip_widget.dart';

/// The numbered seed-phrase word list, shown identically on the display and
/// confirm recovery-phrase screens: one bordered row per word, each with a key
/// chip and the spelled-out position beneath the word.
///
/// A function returning the [BorderedList] itself (rather than a wrapping
/// widget) so [BleedColumn]'s type check sees the list and lets it bleed to
/// the screen edges like every other row list.
BorderedList seedPhraseList(BuildContext context, List<String> seedPhrase) {
  final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

  return BorderedList.column(
    children: [
      for (int i = 0; i < seedPhrase.length; i++)
        ListTile(
          contentPadding: listTilePadding,
          leading: const IconChip(icon: PhosphorIconsRegular.key),
          // Stack word/number in the title (not subtitle) to keep the tile's
          // single-line height instead of growing to two-line.
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(seedPhrase[i], style: mediumStyle),
              Text(
                spellOutNumber(i + 1),
                style: smallStyle.copyWith(color: onSurfaceVariant),
              ),
            ],
          ),
        ),
    ],
  );
}
