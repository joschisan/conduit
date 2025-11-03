import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/screens/settings_screen.dart';
import 'package:conduit/widgets/async_action_button.dart';
import 'package:conduit/utils/notification_utils.dart';
import 'package:conduit/widgets/seed_phrase_grid.dart';

class ConfirmSeedScreen extends StatelessWidget {
  final DatabaseWrapper db;
  final List<String> seedPhrase;

  const ConfirmSeedScreen({
    super.key,
    required this.db,
    required this.seedPhrase,
  });

  Future<void> _recoverWallet(BuildContext context) async {
    final mnemonic = await parseMnemonic(words: seedPhrase);

    if (mnemonic == null) {
      if (context.mounted) {
        NotificationUtils.showError(context, 'Invalid seed phrase');
      }
      return;
    }

    final clientFactory = await ConduitClientFactory.init(
      db: db,
      mnemonic: mnemonic,
    );

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => SettingsScreen(clientFactory: clientFactory),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Seed Phrase')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: SeedPhraseGrid(words: seedPhrase)),
              AsyncActionButton(
                text: 'Confirm Seed Phrase',
                onPressed: () => _recoverWallet(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
