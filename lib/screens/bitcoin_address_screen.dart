import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/widgets/qr_code_widget.dart';
import 'package:conduit/widgets/async_action_button.dart';
import 'package:conduit/drawers/generate_address_drawer.dart';
import 'package:conduit/utils/notification_utils.dart';

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
    GenerateAddressDrawer.show(context, onConfirm: _generateNewAddress);
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
      NotificationUtils.showError(context, 'Failed to generate address');
    }
  }

  Future<void> _recheckAddress() async {
    final tweakIdx = addresses[currentIndex].$1;
    await widget.client.onchainRecheckAddress(tweakIdx: tweakIdx);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
          child:
              addresses.isEmpty ? _buildEmptyState() : _buildAddressContent(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'Tap the + icon in the top right corner to generate for first bitcoin address...',
        style: TextStyle(
          fontSize: 18,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildAddressContent() {
    final currentAddress = addresses[currentIndex].$2;
    final currentPosition = currentIndex + 1;
    final totalAddresses = addresses.length;
    final hasPrevious = currentIndex > 0;
    final hasNext = currentIndex < addresses.length - 1;

    return Column(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: Icon(
                    Icons.currency_bitcoin,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              QrCodeWidget(data: currentAddress),
              Expanded(
                child: Center(
                  child: Row(
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
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, size: 20),
                        onPressed: hasNext ? _nextAddress : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        AsyncActionButton(text: 'Recheck Address', onPressed: _recheckAddress),
      ],
    );
  }
}
