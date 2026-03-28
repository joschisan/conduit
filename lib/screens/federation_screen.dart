import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/events.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/widgets/animated_balance_widget.dart';
import 'package:conduit/widgets/recent_payments_widget.dart';
import 'package:conduit/screens/invoice_amount_screen.dart';
import 'package:conduit/screens/ecash_amount_screen.dart';
import 'package:conduit/screens/onchain_address_screen.dart';
import 'package:conduit/drawers/scanner_drawer.dart';
import 'package:conduit/drawers/payment_details_drawer.dart';
import 'package:conduit/screens/connection_status_screen.dart';
import 'package:conduit/bridge_generated.dart/lnurl.dart';
import 'package:conduit/drawers/ecash_drawer.dart';
import 'package:conduit/drawers/lightning_invoice_drawer.dart';
import 'package:conduit/drawers/lnurl_drawer.dart';
import 'package:conduit/drawers/onchain_address_drawer.dart';
import 'package:conduit/utils/notification_utils.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/screens/display_contacts_screen.dart';
import 'package:conduit/screens/lightning_address_entry_screen.dart';
import 'package:conduit/drawers/expiration_drawer.dart';
import 'package:flutter/services.dart';

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
  late final Stream<RecentPaymentsUpdate> _eventStream;
  late final Stream<int> _balanceStream;
  late final Stream<List<(String, bool)>> _connectionStream;
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  bool _balanceHidden = true;
  int? _expirationDate;
  InviteCodeWrapper? _expirationSuccessor;
  @override
  void initState() {
    super.initState();
    _eventStream = widget.client.subscribeEventLog();
    _balanceStream = widget.client.subscribeBalance();
    _connectionStream = widget.client.subscribeConnectionStatus();
    _initDeepLinks();
    _fetchExpirationStatus();
  }

  Future<void> _fetchExpirationStatus() async {
    final date = await widget.client.expirationDate();
    if (date == null || !mounted) return;

    final successor = await widget.client.expirationSuccessor();

    if (!mounted) return;

    setState(() {
      _expirationDate = date;
      _expirationSuccessor = successor;
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    widget.client.shutdown();
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
        (dynamic result) => LightningInvoiceDrawer.show(
          context,
          client: widget.client,
          invoice: result,
        ),
      ),
      (
        parseOobNotes(notes: input),
        (dynamic result) =>
            EcashDrawer.show(context, client: widget.client, notes: result),
      ),
      (
        parseBitcoinAddress(address: input),
        (dynamic result) => OnchainAddressDrawer.show(
          context,
          client: widget.client,
          address: result,
        ),
      ),
      (
        parseLnurl(request: input),
        (dynamic result) => LnurlDrawer.show(
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
        builder: (_) => InvoiceAmountScreen(client: widget.client),
      ),
    );
  }

  void _onSendEcash() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EcashAmountScreen(client: widget.client),
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
              (context) => OnchainAddressScreen(
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

  void _onLightningAddress() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => LightningAddressEntryScreen(
              client: widget.client,
              clientFactory: widget.clientFactory,
            ),
      ),
    );
  }

  void _onContacts() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => DisplayContactsScreen(
              client: widget.client,
              clientFactory: widget.clientFactory,
            ),
      ),
    );
  }

  void _showExpirationDrawer() {
    if (_expirationDate case final date?) {
      ExpirationDrawer.show(
        context,
        clientFactory: widget.clientFactory,
        date: date,
        successor: _expirationSuccessor,
      );
    }
  }

  void _onScan() {
    ScannerDrawer.show(
      context,
      client: widget.client,
      clientFactory: widget.clientFactory,
    );
  }

  void _showEventDetails(ConduitPayment event) {
    PaymentDetailsDrawer.show(context, event: event);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<List<(String, bool)>>(
          stream: _connectionStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox.shrink();
            }
            final statuses = snapshot.data!;
            final connected = statuses.where((s) => s.$2).length;
            final fraction = connected / statuses.length;
            final color = Theme.of(context).colorScheme.primary;
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) => ConnectionStatusScreen(client: widget.client),
                    ),
                  ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: fraction),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  builder: (context, value, _) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 4,
                        color: color,
                        backgroundColor: color.withValues(alpha: 0.3),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.at, size: smallIconSize),
            onPressed: _onLightningAddress,
          ),
          IconButton(
            icon: const Icon(PhosphorIconsRegular.users, size: smallIconSize),
            onPressed: _onContacts,
          ),
          IconButton(
            icon: const Icon(PhosphorIconsRegular.qrCode, size: smallIconSize),
            onPressed: _onScan,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 64),
            GestureDetector(
              onTap: () {
                setState(() => _balanceHidden = !_balanceHidden);
              },
              child: StreamBuilder<int>(
                stream: _balanceStream,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    if (_balanceHidden) {
                      return Text.rich(
                        TextSpan(text: '* * * *', style: heroStyle),
                      );
                    }
                    return AnimatedBalanceDisplay(snapshot.data!);
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
                  icon: PhosphorIconsRegular.lightning,
                  label: 'Lightning',
                  onTap: _onCreateInvoice,
                ),
                _CircularActionButton(
                  icon: PhosphorIconsRegular.link,
                  label: 'Onchain',
                  onTap: _onReceiveBitcoin,
                ),
                _CircularActionButton(
                  icon: PhosphorIconsRegular.coinVertical,
                  label: 'eCash',
                  onTap: _onSendEcash,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_expirationDate != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ExpirationWarningCard(onTap: _showExpirationDrawer),
              ),
            RecentPayments(
              client: widget.client,
              stream: _eventStream,
              onTransactionTap: _showEventDetails,
            ),
          ],
        ),
      ),
    );
  }
}

class _CircularActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CircularActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Icon(
              icon,
              size: mediumIconSize,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: smallStyle),
        ],
      ),
    );
  }
}

class _ExpirationWarningCard extends StatelessWidget {
  final VoidCallback onTap;

  const _ExpirationWarningCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: borderRadiusLarge,
          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(
              PhosphorIconsRegular.moon,
              color: Colors.amber[700],
              size: smallIconSize,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Federation Expiry',
                style: mediumStyle.copyWith(color: Colors.amber[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
