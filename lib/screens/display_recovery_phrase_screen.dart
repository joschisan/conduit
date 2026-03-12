import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/widgets/recovery_phrase_grid_widget.dart';

class DisplayRecoveryPhraseScreen extends StatelessWidget {
  final List<String> seedPhrase;

  const DisplayRecoveryPhraseScreen({super.key, required this.seedPhrase});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Recovery Phrase')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RecoveryPhraseGrid(words: seedPhrase),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      'Your recovery phrase is the only way to restore your wallet '
                      'if you lose access to this device. Store it safely.',
                      textAlign: TextAlign.center,
                      style: smallStyle.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
