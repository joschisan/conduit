import 'dart:async';
import 'package:flutter/material.dart';
import 'package:conduit/screens/input_seed_screen.dart';
import 'package:conduit/screens/base_screen.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/widgets/async_action_button.dart';

const _variants = [
  (Icons.bolt, 'Lightning'),
  (Icons.currency_bitcoin, 'Onchain'),
  (Icons.toll, 'eCash'),
];

class LandingScreen extends StatefulWidget {
  final DatabaseWrapper db;

  const LandingScreen({super.key, required this.db});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _pageController = PageController();
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

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
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 64,
                        child: PageView.builder(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            final (icon, name) =
                                _variants[index % _variants.length];
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  icon,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Powered by Fedimint',
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                'New to Conduit?',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 8),
              AsyncActionButton(
                text: 'Generate New Wallet',
                onPressed: () async {
                  final mnemonic = await generateMnemonic();

                  final clientFactory = await ConduitClientFactory.init(
                    db: widget.db,
                    mnemonic: mnemonic,
                  );

                  if (!context.mounted) return;

                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder:
                          (context) => BaseScreen(clientFactory: clientFactory),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Already have a wallet?',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 8),
              AsyncActionButton(
                text: 'Enter Recovery Phrase',
                onPressed: () async {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (context) => InputSeedScreen(
                            db: widget.db,
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
