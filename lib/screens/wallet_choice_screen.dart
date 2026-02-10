import 'package:flutter/material.dart';
import 'package:conduit/screens/input_seed_screen.dart';
import 'package:conduit/screens/settings_screen.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/widgets/async_action_button.dart';

class WalletChoiceScreen extends StatelessWidget {
  final DatabaseWrapper db;

  const WalletChoiceScreen({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Conduit Logo
              Expanded(
                child: Center(
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      theme.colorScheme.primary,
                      BlendMode.srcIn,
                    ),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 200,
                      height: 200,
                    ),
                  ),
                ),
              ),

              Text(
                'New to Conduit?',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 8),
              AsyncActionButton(
                text: 'Generate New Wallet',
                onPressed: () async {
                  final mnemonic = await generateMnemonic();

                  final clientFactory = await ConduitClientFactory.init(
                    db: db,
                    mnemonic: mnemonic,
                  );

                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                SettingsScreen(clientFactory: clientFactory),
                      ),
                    );
                  }
                },
              ),

              const SizedBox(height: 24),

              Text(
                'Already have a wallet?',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 8),
              AsyncActionButton(
                text: 'Enter Seed Phrase',
                onPressed: () async {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (context) => InputSeedScreen(
                            db: db,
                            partialSeedPhrase: const [],
                          ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
