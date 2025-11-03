import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/widgets/amount_display.dart';
import 'package:conduit/widgets/event_transactions_list.dart';
import 'package:conduit/screens/lightning_receive_amount_screen.dart';
import 'package:conduit/screens/ecash_send_amount_screen.dart';
import 'package:conduit/screens/bitcoin_address_screen.dart';
import 'package:conduit/screens/settings_screen.dart';
import 'package:conduit/drawers/scanner_drawer.dart';
import 'package:conduit/drawers/event_details_drawer.dart';
import 'package:conduit/utils/notification_utils.dart';

class HomeScreen extends StatefulWidget {
  final ConduitClient client;
  final ConduitClientFactory clientFactory;

  const HomeScreen({
    super.key,
    required this.client,
    required this.clientFactory,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _onCreateInvoice() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LightningReceiveAmountScreen(client: widget.client),
      ),
    );
  }

  void _onSendEcash() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EcashSendAmountScreen(client: widget.client),
      ),
    );
  }

  void _onReceiveBitcoin() async {
    try {
      final addressesList = await widget.client.onchainListAddresses();
      // Addresses already sorted ascending by Rust (oldest first, newest last)

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (context) => BitcoinAddressScreen(
                client: widget.client,
                addressesList: addressesList,
              ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      NotificationUtils.showError(context, 'Failed to load addresses');
    }
  }

  void _onScan() {
    ScannerDrawer.show(context, client: widget.client);
  }

  void _showEventDetails(ConduitPayment event) {
    EventDetailsDrawer.show(context, event: event);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder:
                    (_) => SettingsScreen(clientFactory: widget.clientFactory),
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _onScan,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 32),
            StreamBuilder<int>(
              stream: widget.client.subscribeBalance(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return AmountDisplay(snapshot.data!);
                } else {
                  return const CircularProgressIndicator();
                }
              },
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CircularActionButton(
                  icon: Icons.bolt,
                  onTap: _onCreateInvoice,
                ),
                _CircularActionButton(
                  icon: Icons.currency_bitcoin,
                  onTap: _onReceiveBitcoin,
                ),
                _CircularActionButton(icon: Icons.toll, onTap: _onSendEcash),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: EventTransactionsList(
                stream: widget.client.subscribeEventLog(),
                onTransactionTap: _showEventDetails,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircularActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircularActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.primary,
        ),
        child: Icon(
          icon,
          size: 34,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }
}
