import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/screens/home_screen.dart';

class RecoveryScreen extends StatefulWidget {
  final ConduitClient client;

  const RecoveryScreen({super.key, required this.client});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  late final Future<void> _recoveryFuture;

  @override
  void initState() {
    super.initState();
    _recoveryFuture = _performRecovery();
  }

  Future<void> _performRecovery() async {
    await widget.client.waitForAllRecoveries();

    // Defer navigation until after the current frame completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(client: widget.client)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: FutureBuilder<void>(
          future: _recoveryFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildFailedUI(snapshot.error.toString());
            }
            return _buildRecoveringUI();
          },
        ),
      ),
    );
  }

  Widget _buildRecoveringUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 24),
        Text(
          'Recovering funds...',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }

  Widget _buildFailedUI(String error) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 24),
          Text(
            'Recovery failed',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Text(
            error,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
