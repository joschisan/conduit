import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_links/app_links.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/events.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/widgets/animated_balance_widget.dart';
import 'package:conduit/widgets/amount_visibility.dart';
import 'package:conduit/utils/currency_utils.dart';
import 'package:conduit/widgets/settings_card_widget.dart';
import 'package:conduit/widgets/recent_payments_widget.dart';
import 'package:conduit/screens/invoice_amount_screen.dart';
import 'package:conduit/screens/ecash_amount_screen.dart';
import 'package:conduit/screens/onchain_address_screen.dart';
import 'package:conduit/screens/wallet_v2_receive_screen.dart';
import 'package:conduit/drawers/scanner_drawer.dart';
import 'package:conduit/drawers/payment_details_drawer.dart';
import 'package:conduit/screens/connection_status_screen.dart';
import 'package:conduit/bridge_generated.dart/lnurl.dart';
import 'package:conduit/drawers/ecash_drawer.dart';
import 'package:conduit/drawers/lightning_invoice_drawer.dart';
import 'package:conduit/drawers/lnurl_drawer.dart';
import 'package:conduit/screens/onchain_amount_screen.dart';
import 'package:conduit/utils/notification_utils.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/screens/display_contacts_screen.dart';
import 'package:conduit/screens/lightning_address_entry_screen.dart';
import 'package:conduit/drawers/invite_drawer.dart';
import 'package:conduit/drawers/recovery_drawer.dart';
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
  int? _expirationDate;
  InviteCodeWrapper? _expirationSuccessor;
  // Single cycling control over how the balance reads: sats → fiat → hidden.
  // Starts hidden so balances aren't exposed on open.
  BalanceDisplay _balanceDisplay = BalanceDisplay.hidden;

  // Whether a cached exchange rate exists, so the fiat step is reachable.
  // `satsToFiat` is a cache-only sync read returning null when no fresh rate
  // is stored.
  bool get _fiatAvailable => widget.client.satsToFiat(amountSats: 0) != null;

  void _cycleBalanceDisplay() {
    setState(() {
      // Skip the fiat step entirely when no rate is cached.
      _balanceDisplay = switch (_balanceDisplay) {
        BalanceDisplay.sats =>
          _fiatAvailable ? BalanceDisplay.fiat : BalanceDisplay.hidden,
        BalanceDisplay.fiat => BalanceDisplay.hidden,
        BalanceDisplay.hidden => BalanceDisplay.sats,
      };
    });
  }

  @override
  void initState() {
    super.initState();
    _eventStream = widget.client.subscribeEventLog();
    _balanceStream = widget.client.subscribeBalance();
    _connectionStream = widget.client.subscribeConnectionStatus();
    _initDeepLinks();
    _fetchExpirationStatus();
    // Warm the exchange-rate cache so the fiat toggle is reachable and the
    // fiat figure renders from cache without blocking. Repaint once it lands.
    widget.client.prefetchExchangeRates().then((_) {
      if (mounted) setState(() {});
    });
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
        parseEcash(notes: input),
        (dynamic result) =>
            EcashDrawer.show(context, client: widget.client, notes: result),
      ),
      (
        parseBitcoinAddress(address: input),
        (dynamic result) => Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) =>
                    OnchainAmountScreen(client: widget.client, address: result),
          ),
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
      final v2Address = await widget.client.walletV2Receive();

      if (!mounted) return;

      if (v2Address != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) => WalletV2ReceiveScreen(
                  address: v2Address,
                  client: widget.client,
                ),
          ),
        );
      } else {
        // Addresses already sorted ascending by Rust (oldest first, newest last)
        final addressesList = await widget.client.onchainListAddresses();

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
      }
    } catch (e) {
      if (!mounted) return;
      NotificationUtils.showError(context, 'Failed to load address');
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

  Widget _buildExpiryCard(int date) {
    final formatted = DateFormat.MMMMd().format(
      DateTime.fromMillisecondsSinceEpoch(date * 1000),
    );
    final successor = _expirationSuccessor;

    return SettingsCard(
      icon: PhosphorIconsRegular.moon,
      iconColor: Colors.amber,
      title: 'Expires on $formatted',
      subtitle:
          successor != null ? 'Tap to join successor' : 'Migrate your funds',
      onTap:
          successor != null
              ? () => InviteDrawer.show(
                context,
                invite: successor,
                onJoin: _joinSuccessor,
                onRecover: _recoverSuccessor,
              )
              : null,
    );
  }

  Future<void> _joinSuccessor(InviteCodeWrapper invite) async {
    final client = await widget.clientFactory.join(invite: invite);

    if (!mounted) return;

    _openSuccessor(client);
  }

  Future<void> _recoverSuccessor(InviteCodeWrapper invite) async {
    final client = await widget.clientFactory.recover(invite: invite);

    if (!mounted) return;

    _openSuccessor(client);
  }

  /// Closes the invite drawer and swaps the current federation screen for the
  /// successor's, routing through the recovery drawer when it has recoveries.
  void _openSuccessor(ConduitClient client) {
    Navigator.of(context).pop();

    if (client.hasPendingRecoveries()) {
      RecoveryDrawer.show(
        context,
        client: client,
        clientFactory: widget.clientFactory,
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (_) => FederationScreen(
                client: client,
                clientFactory: widget.clientFactory,
              ),
        ),
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
              borderRadius: cornerRadius,
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
      body: AmountDisplay(
        display: _balanceDisplay,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                // Tapping the balance cycles display sats → fiat → hidden,
                // the same control as the app-bar switcher.
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _cycleBalanceDisplay,
                  // One subscription to the single-subscription balance stream,
                  // lifted above the hero so toggling never re-listens to it.
                  child: StreamBuilder<int>(
                    stream: _balanceStream,
                    builder:
                        (context, snapshot) => _BalanceHero(
                          sats: snapshot.data ?? 0,
                          client: widget.client,
                          display: _balanceDisplay,
                        ),
                  ),
                ),
              ),
              if (_expirationDate case final date?)
                _buildExpiryCard(date)
              else
                const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.05),
                    borderRadius: cornerRadius,
                  ),
                  child: Row(
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
                ),
              ),
              const SizedBox(height: 16),
              RecentPayments(
                client: widget.client,
                stream: _eventStream,
                onTransactionTap: _showEventDetails,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hero balance shown above the action row. Masked away when hidden, shown in
/// fiat when toggled (falling back to sats until a rate is cached), otherwise
/// the animated sats amount.
class _BalanceHero extends StatelessWidget {
  final int sats;
  final ConduitClient client;
  final BalanceDisplay display;

  const _BalanceHero({
    required this.sats,
    required this.client,
    required this.display,
  });

  @override
  Widget build(BuildContext context) {
    // Fiat when toggled and a rate is cached; otherwise the sats display
    // (and a "Bitcoin" unit label to match).
    final fiat =
        display == BalanceDisplay.fiat ? cachedFiatAmount(client, sats) : null;
    final hidden = display == BalanceDisplay.hidden;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // Stretch to full width so the centered text aligns to the screen
        // centre rather than shrink-wrapping the number.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hidden masks the amount with the same dots used for payment-row
          // amounts, keeping the " sat" suffix and layout in place.
          if (hidden)
            Text.rich(
              textAlign: TextAlign.center,
              const TextSpan(
                children: [
                  TextSpan(text: maskedAmount, style: heroStyle),
                  TextSpan(text: ' sat', style: largeStyle),
                ],
              ),
            )
          else if (fiat != null)
            AnimatedBalance(
              sats: sats,
              style: heroStyle,
              textAlign: TextAlign.center,
              // Convert each tweened sats value to fiat so it counts up on the
              // same tween as the sats view.
              formatter: (s) => cachedFiatAmount(client, s)?.amount ?? '',
            )
          else
            AnimatedBalance(
              sats: sats,
              style: heroStyle,
              unitStyle: largeStyle,
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 8),
          Text(
            fiat?.currency ?? 'Bitcoin',
            textAlign: TextAlign.center,
            style: mediumStyle.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
