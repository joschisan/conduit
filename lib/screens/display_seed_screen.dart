import 'package:flutter/material.dart';
import 'package:conduit/widgets/seed_phrase_grid.dart';

class DisplaySeedScreen extends StatelessWidget {
  final List<String> seedPhrase;

  const DisplaySeedScreen({super.key, required this.seedPhrase});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seed Phrase')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SeedPhraseGrid(words: seedPhrase),
        ),
      ),
    );
  }
}
