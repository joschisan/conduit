import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart' hide State;
import 'package:intl/intl.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/widgets/amount_display.dart';
import 'package:conduit/widgets/event_transactions_list.dart';
import 'package:conduit/widgets/multi_scanner_widget.dart';
import 'package:conduit/screens/amount_screen.dart';
import 'package:conduit/screens/display_invoice_screen.dart';
import 'package:conduit/screens/display_ecash_screen.dart';
import 'package:conduit/screens/bitcoin_address_screen.dart';
import 'package:conduit/screens/settings_screen.dart';
import 'package:conduit/utils/notification_utils.dart';
import 'package:conduit/utils/fp_utils.dart';
import 'package:conduit/utils/auth_utils.dart';
import 'package:conduit/utils/drawer_utils.dart';

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
        builder:
            (context) => AmountScreen(
              client: widget.client,
              onAmountSubmitted: _handleCreateInvoice,
              showLnurlButton: true,
            ),
      ),
    );
  }

  void _onSendEcash() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => AmountScreen(
              client: widget.client,
              onAmountSubmitted: _handleSendEcash,
            ),
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load addresses: $e')));
    }
  }

  TaskEither<String, void> _handleCreateInvoice(
    int amountSats,
    BuildContext context,
    ConduitClient client,
  ) {
    return safeTask(() async {
      final invoice = await client.lnReceive(amountSat: amountSats);

      if (!context.mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (_) => DisplayInvoiceScreen(
                invoice: invoice,
                amount: amountSats,
                description: '',
              ),
        ),
      );
    });
  }

  TaskEither<String, void> _handleSendEcash(
    int amountSats,
    BuildContext context,
    ConduitClient client,
  ) {
    return safeTask(() async {
      final authenticated = await requireBiometricAuth(
        context,
        'Please authenticate to send eCash',
      );

      if (!authenticated) {
        throw Exception('Authentication required');
      }

      final notes = await client.ecashSend(amountSat: amountSats);

      if (!context.mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (_) => DisplayEcashScreen(
                encoder: OobNotesEncoder(notes: notes),
                ecashNotes: notes.toString(),
                amount: amountSats,
              ),
        ),
      );
    });
  }

  void _onScan() {
    showStandardDrawer(
      context: context,
      child: MultiScannerWidget(
        client: widget.client,
        onLightningPayment: _handleLightningPayment,
        onEcashRedeem: _handleEcashRedeem,
        onLnurlPayment: _handleLnurlPayment,
        onBitcoinWithdrawal: _handleBitcoinWithdrawal,
      ),
    );
  }

  TaskEither<String, void> _handleLightningPayment(
    Bolt11InvoiceWrapper invoice,
  ) {
    return safeTask(() async {
      final authenticated = await requireBiometricAuth(
        context,
        'Please authenticate to send payment',
      );

      if (!authenticated) {
        throw Exception('Authentication required');
      }

      await widget.client.lnSend(invoice: invoice);

      if (!context.mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  TaskEither<String, void> _handleEcashRedeem(OobNotesWrapper ecash) {
    return safeTask(() async {
      await widget.client.ecashReceive(notes: ecash);

      if (!context.mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  TaskEither<String, void> _handleLnurlPayment(
    LnurlWrapper lnurl,
    int amountSats,
  ) {
    return safeTask(() async {
      // Resolve LNURL to get invoice
      final invoice = await resolveLnurl(lnurl: lnurl, amountSats: amountSats);

      if (!context.mounted) return;

      // Require biometric authentication
      final authenticated = await requireBiometricAuth(
        context,
        'Please authenticate to send payment',
      );

      if (!authenticated) {
        throw Exception('Authentication required');
      }

      await widget.client.lnSend(invoice: invoice);
    });
  }

  TaskEither<String, void> _handleBitcoinWithdrawal(
    BitcoinAddressWrapper address,
    int amountSats,
  ) {
    return safeTask(() async {
      // Require biometric authentication
      final authenticated = await requireBiometricAuth(
        context,
        'Please authenticate to send Bitcoin',
      );

      if (!authenticated) {
        throw Exception('Authentication required');
      }

      await widget.client.onchainSend(address: address, amountSats: amountSats);
    });
  }

  void _showEventDetails(ConduitPayment event) {
    showStandardDrawer(
      context: context,
      topRightButton:
          event.oob != null
              ? IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: event.oob!));
                  NotificationUtils.showCopy(
                    context,
                    'eCash copied to clipboard',
                  );
                },
              )
              : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                child: Icon(
                  switch (event.paymentType) {
                    PaymentType.lightning => Icons.bolt,
                    PaymentType.bitcoin => Icons.currency_bitcoin,
                    PaymentType.ecash => Icons.toll,
                  },
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDateTime(event.timestamp),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: AmountDisplay(event.amountSats, fee: event.feeSats),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

    return DateFormat('MMM dd, HH:mm:ss').format(dateTime);
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
            const SizedBox(height: 24),
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
