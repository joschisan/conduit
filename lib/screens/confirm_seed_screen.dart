import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/screens/settings_screen.dart';
import 'package:conduit/widgets/navigation_button.dart';

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invalid seed phrase')));
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Seed Phrase')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: GridView.builder(
                  itemCount: 12,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 3.5,
                  ),
                  itemBuilder: (context, index) {
                    final word = seedPhrase[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Text(
                            '${index + 1}.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              word,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              NavigationButton(
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
