import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart' hide State;
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/widgets/qr_code_widget.dart';
import 'package:conduit/widgets/copy_button.dart';
import 'package:conduit/widgets/async_action_button.dart';
import 'package:conduit/widgets/navigation_button.dart';
import 'package:conduit/utils/fp_utils.dart';
import 'package:conduit/utils/drawer_utils.dart';

class BitcoinAddressScreen extends StatefulWidget {
  final ConduitClient client;
  final List<(int, String)> addressesList;

  const BitcoinAddressScreen({
    super.key,
    required this.client,
    required this.addressesList,
  });

  @override
  State<BitcoinAddressScreen> createState() => _BitcoinAddressScreenState();
}

class _BitcoinAddressScreenState extends State<BitcoinAddressScreen> {
  late List<(int, String)> addresses;
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    addresses = widget.addressesList;
    // Start with the most recent address (index 0 after sorting)
    currentIndex = addresses.isEmpty ? 0 : addresses.length - 1;
  }

  void _previousAddress() {
    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
      });
    }
  }

  void _nextAddress() {
    if (currentIndex < addresses.length - 1) {
      setState(() {
        currentIndex++;
      });
    }
  }

  void _showGenerateConfirmation() {
    showStandardDrawer(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                child: Icon(
                  Icons.add,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Generate New Bitcoin Address?',
                style: TextStyle(fontSize: 18),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          NavigationButton(
            text: 'Confirm',
            onPressed: () {
              Navigator.of(context).pop();
              _generateNewAddress();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _generateNewAddress() async {
    try {
      await widget.client.onchainReceiveAddress();
      final newAddresses = await widget.client.onchainListAddresses();
      setState(() {
        // Addresses already sorted ascending by Rust (oldest first, newest last)
        addresses = newAddresses;
        currentIndex = addresses.length - 1; // Show newest address
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to generate address: $e')));
    }
  }

  TaskEither<String, void> _recheckAddress() {
    return safeTask(() async {
      final tweakIdx = addresses[currentIndex].$1;
      await widget.client.onchainRecheckAddress(tweakIdx: tweakIdx);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (addresses.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Bitcoin Addresses'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showGenerateConfirmation,
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                'Tap the + icon in the top right corner to generate for first bitcoin address...',
                style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    final (tweakIdx, currentAddress) = addresses[currentIndex];
    final currentPosition = currentIndex + 1;
    final totalAddresses = addresses.length;

    final hasPrevious = currentIndex > 0;
    final hasNext = currentIndex < addresses.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bitcoin Addresses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showGenerateConfirmation,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios, size: 20),
                          onPressed: hasPrevious ? _previousAddress : null,
                        ),
                        Text(
                          '$currentPosition',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Container(
                            width: 1,
                            height: 24,
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        Text(
                          '$totalAddresses',
                          style: TextStyle(
                            fontSize: 20,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios, size: 20),
                          onPressed: hasNext ? _nextAddress : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    QrCodeWidget(data: currentAddress),
                    const SizedBox(height: 16),
                    CopyButton(data: currentAddress, message: 'Address copied'),
                  ],
                ),
              ),
              AsyncActionButton(
                text: 'Recheck Address',
                onPressed: _recheckAddress,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
