import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/events.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/widgets/amount_display.dart';
import 'package:conduit/widgets/event_transactions_list.dart';
import 'package:conduit/screens/lightning_receive_amount_screen.dart';
import 'package:conduit/screens/ecash_send_amount_screen.dart';
import 'package:conduit/screens/bitcoin_address_screen.dart';
import 'package:conduit/drawers/scanner_drawer.dart';
import 'package:conduit/drawers/event_details_drawer.dart';
import 'package:conduit/drawers/ecash_receive_drawer.dart';
import 'package:conduit/drawers/lightning_payment_drawer.dart';
import 'package:conduit/drawers/lnurl_prompt_drawer.dart';
import 'package:conduit/drawers/bitcoin_address_prompt_drawer.dart';
import 'package:conduit/bridge_generated.dart/lnurl.dart';
import 'package:conduit/utils/notification_utils.dart';
import 'package:conduit/screens/contacts_screen.dart';

class FederationScreen extends StatefulWidget {
  final ConduitClient client;
  final ConduitClientFactory clientFactory;

  const FederationScreen({
    super.key,
    required this.client,
    required this.clientFactory,
  });

  @override
  State<FederationScreen> createState() => _FederationScreenState();
}

class _FederationScreenState extends State<FederationScreen> {
  late final Stream<ConduitEvent> _eventStream;
  late final Stream<int> _balanceStream;
  late final Stream<List<bool>> _connectionStream;
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  bool _balanceHidden = true;

  @override
  void initState() {
    super.initState();
    _eventStream = widget.client.subscribeEventLog();
    _balanceStream = widget.client.subscribeBalance();
    _connectionStream = widget.client.subscribeConnectionStatus();
    _initDeepLinks();
    _backupToFederation();
  }

  Future<void> _backupToFederation() async {
    try {
      await widget.client.backupToFederation();
    } catch (e) {
      if (mounted) {
        NotificationUtils.showError(context, 'Backup failed');
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    _linkSubscription = _appLinks.uriLinkStream.listen(_handleDeepLink);

    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    final input = uri.toString();

    final parsers = [
      (
        parseBolt11Invoice(invoice: input),
        (dynamic result) => LightningPaymentDrawer.show(
          context,
          client: widget.client,
          invoice: result,
        ),
      ),
      (
        parseOobNotes(notes: input),
        (dynamic result) => EcashReceiveDrawer.show(
          context,
          client: widget.client,
          notes: result,
        ),
      ),
      (
        parseBitcoinAddress(address: input),
        (dynamic result) => BitcoinAddressPromptDrawer.show(
          context,
          client: widget.client,
          address: result,
        ),
      ),
      (
        parseLnurl(request: input),
        (dynamic result) => LnurlPromptDrawer.show(
          context,
          client: widget.client,
          clientFactory: widget.clientFactory,
          lnurl: result,
        ),
      ),
    ];

    for (final (result, showDrawer) in parsers) {
      if (result != null) {
        showDrawer(result);
        return;
      }
    }
  }

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

  void _onContacts() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => ContactsScreen(
              client: widget.client,
              clientFactory: widget.clientFactory,
            ),
      ),
    );
  }

  void _onScan() {
    ScannerDrawer.show(
      context,
      client: widget.client,
      clientFactory: widget.clientFactory,
    );
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: StreamBuilder<List<bool>>(
          stream: _connectionStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox.shrink();
            }
            return Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children:
                  snapshot.data!.map((connected) {
                    return Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            connected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    );
                  }).toList(),
            );
          },
        ),
        centerTitle: false,
        actions: [
          IconButton(icon: const Icon(Icons.people), onPressed: _onContacts),
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
            const SizedBox(height: 64),
            GestureDetector(
              onTap: () => setState(() => _balanceHidden = !_balanceHidden),
              child: StreamBuilder<int>(
                stream: _balanceStream,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    if (_balanceHidden) {
                      final textColor = Theme.of(context).colorScheme.onSurface;
                      return RichText(
                        text: TextSpan(
                          text: '* * * *',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      );
                    }
                    return AmountDisplay(snapshot.data!);
                  } else {
                    return const CircularProgressIndicator();
                  }
                },
              ),
            ),
            const SizedBox(height: 64),
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
                stream: _eventStream,
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
