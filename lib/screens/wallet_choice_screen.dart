import 'package:flutter/material.dart';
import 'package:conduit/screens/input_seed_screen.dart';
import 'package:conduit/screens/settings_screen.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/widgets/navigation_button.dart';

class WalletChoiceScreen extends StatelessWidget {
  final DatabaseWrapper db;

  const WalletChoiceScreen({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              NavigationButton(
                text: 'Generate New Wallet',
                onPressed: () async {
                  final mnemonic = await generateMnemonic();
                  final initializedDb = await InitializedDatabase.init(
                    db: db,
                    mnemonic: mnemonic,
                  );

                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                SettingsScreen(initializedDb: initializedDb),
                      ),
                    );
                  }
                },
              ),

              const SizedBox(height: 16),

              NavigationButton(
                text: 'Recover Wallet',
                onPressed: () {
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
