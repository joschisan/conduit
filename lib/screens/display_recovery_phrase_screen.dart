import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/widgets/bleed_column_widget.dart';
import 'package:conduit/widgets/seed_phrase_list_widget.dart';

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
            SeedPhraseList(seedPhrase: seedPhrase),
          ],
        ),
      ),
    );
  }
}
