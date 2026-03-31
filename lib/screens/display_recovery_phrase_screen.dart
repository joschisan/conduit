import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';

class DisplayRecoveryPhraseScreen extends StatelessWidget {
  final List<String> seedPhrase;

  const DisplayRecoveryPhraseScreen({super.key, required this.seedPhrase});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Recovery Phrase')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16).copyWith(bottom: 32),
        child: Column(
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
            for (int i = 0; i < seedPhrase.length; i++)
              BorderedList.decorateItem(
                context: context,
                isFirst: i == 0,
                isLast: i == seedPhrase.length - 1,
                child: ListTile(
                  contentPadding: listTilePadding,
                  leading: PhosphorIcon(
                    PhosphorIconsRegular.key,
                    color: theme.colorScheme.primary,
                    size: mediumIconSize,
                  ),
                  title: Text('${i + 1} - ${seedPhrase[i]}', style: mediumStyle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
