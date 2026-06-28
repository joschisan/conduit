import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/utils/number_utils.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/bleed_column_widget.dart';
import 'package:conduit/widgets/icon_chip_widget.dart';

class DisplayRecoveryPhraseScreen extends StatelessWidget {
  final List<String> seedPhrase;

  const DisplayRecoveryPhraseScreen({super.key, required this.seedPhrase});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Recovery Phrase')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
        child: BleedColumn(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'Your recovery phrase is the only way to restore your wallet '
                'if you lose access to this device.',
                textAlign: TextAlign.center,
                style: smallStyle.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 24),
            BorderedList.column(
              children: [
                for (int i = 0; i < seedPhrase.length; i++)
                  ListTile(
                    contentPadding: listTilePadding,
                    leading: const IconChip(icon: PhosphorIconsRegular.key),
                    // Stack word/number in the title (not subtitle) to keep the
                    // tile's single-line height instead of growing to two-line.
                    title: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(seedPhrase[i], style: mediumStyle),
                        Text(
                          spellOutNumber(i + 1),
                          style: smallStyle.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
