import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/widgets/qr_code_widget.dart';
import 'package:conduit/widgets/shareable_data_widget.dart';
import 'package:conduit/drawers/generate_onchain_address_drawer.dart';
import 'package:conduit/utils/notification_utils.dart';

class OnchainAddressScreen extends StatefulWidget {
  final ConduitClient client;
  final List<(int, String)> addressesList;

  const OnchainAddressScreen({
    super.key,
    required this.client,
    required this.addressesList,
  });

  @override
  State<OnchainAddressScreen> createState() => _OnchainAddressScreenState();
}

class _OnchainAddressScreenState extends State<OnchainAddressScreen> {
  late List<(int, String)> addresses;
  late PageController _pageController;
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    addresses = widget.addressesList;
    currentIndex = addresses.isEmpty ? 0 : addresses.length - 1;
    _pageController = PageController(initialPage: currentIndex);

    if (addresses.isEmpty) {
      _generateNewAddress();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showGenerateConfirmation() {
    GenerateOnchainAddressDrawer.show(
      context,
      onConfirm: () => _generateNewAddress(notify: true),
    );
  }

  Future<void> _generateNewAddress({bool notify = false}) async {
    try {
      await widget.client.onchainReceiveAddress();
      final newAddresses = await widget.client.onchainListAddresses();
      setState(() {
        addresses = newAddresses;
        currentIndex = addresses.length - 1;
      });
      _pageController.animateToPage(
        currentIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      if (notify && mounted) {
        NotificationUtils.showSuccess(context, 'Generated onchain address');
      }
    } catch (e) {
      if (!mounted) return;
      NotificationUtils.showError(context, 'Failed to generate address');
    }
  }

  Future<void> _recheckAddress() async {
    final tweakIdx = addresses[currentIndex].$1;
    await widget.client.onchainRecheckAddress(tweakIdx: tweakIdx);
    if (!mounted) return;
    NotificationUtils.showSuccess(context, 'Checking address for payments');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Receive Onchain'),
        actions: [
          if (addresses.isNotEmpty)
            IconButton(
              icon: const Icon(
                PhosphorIconsRegular.arrowsClockwise,
                size: smallIconSize,
              ),
              onPressed: _recheckAddress,
            ),
          IconButton(
            icon: const Icon(PhosphorIconsRegular.plus, size: smallIconSize),
            onPressed: _showGenerateConfirmation,
          ),
        ],
      ),
      body: SafeArea(
        child:
            addresses.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _buildAddressContent(),
      ),
    );
  }

  Widget _buildAddressContent() {
    return PageView.builder(
      controller: _pageController,
      itemCount: addresses.length,
      onPageChanged: (index) {
        setState(() {
          currentIndex = index;
        });
      },
      itemBuilder: (context, index) {
        final address = addresses[index].$2;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 16),
              QrCodeWidget(data: address),
              const SizedBox(height: 16),
              ShareableData(data: address),
              const SizedBox(height: 16),
              Text(
                '${currentIndex + 1} / ${addresses.length}',
                style: largeStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      'Confirmed onchain payments may take a few hours to appear. A reused address must be manually checked for payments.',
                      style: smallStyle.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
