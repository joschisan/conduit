import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:conduit/widgets/icon_chip_widget.dart';
import 'package:conduit/widgets/circular_action_button_widget.dart';
import 'package:conduit/widgets/recent_payments_widget.dart';
import 'package:conduit/screens/display_lnurl_screen.dart';
import 'package:conduit/screens/ecash_amount_screen.dart';
import 'package:conduit/screens/onchain_address_screen.dart';
import 'package:conduit/screens/wallet_v2_receive_screen.dart';
import 'package:conduit/drawers/scanner_drawer.dart';
import 'package:conduit/drawers/payment_details_drawer.dart';
import 'package:conduit/bridge_generated.dart/lnurl.dart';
import 'package:conduit/drawers/ecash_drawer.dart';
import 'package:conduit/drawers/lightning_send_drawer.dart';
import 'package:conduit/drawers/lnurl_drawer.dart';
import 'package:conduit/screens/onchain_amount_screen.dart';
import 'package:conduit/utils/notification_utils.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/screens/display_contacts_screen.dart';
import 'package:conduit/screens/lightning_address_entry_screen.dart';
import 'package:conduit/drawers/invite_drawer.dart';
import 'package:conduit/drawers/recovery_drawer.dart';
import 'package:conduit/drawers/select_federation_drawer.dart';
import 'package:conduit/drawers/settings_drawer.dart';
import 'package:conduit/drawers/remove_federation_drawer.dart';
import 'package:conduit/screens/select_currency_screen.dart';
import 'package:conduit/screens/display_recovery_phrase_screen.dart';
import 'package:conduit/screens/connection_status_screen.dart';
import 'package:conduit/screens/base_screen.dart';
import 'package:conduit/utils/auth_utils.dart';

class FederationScreen extends StatefulWidget {
  final ConduitClient client;
  final ConduitClientFactory clientFactory;
  // The federation's name, when the caller already knows it, so the switcher
  // row renders without an async flicker. Fetched from the client otherwise.
  final String? federationName;

  const FederationScreen({
    super.key,
    required this.client,
    required this.clientFactory,
    this.federationName,
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
  String? _federationName;
  // Set while a background recovery runs on a wallet that is already usable
  // (its modules stay in the registry mid-recovery). Drives the spinner and
  // "Recovering funds" progress on the federation selector row.
  bool _recovering = false;
  // Overall recovery percentage (0..=100), computed on the Rust side as the
  // minimum across every recovering module.
  int? _recoveryPercent;
  StreamSubscription<int>? _recoverySubscription;
  // Single cycling control over how the balance reads: sats → fiat → hidden.
  // Starts hidden so balances aren't exposed on open.
  BalanceDisplay _balanceDisplay = BalanceDisplay.hidden;

  // Whether the balance is showing fiat, passed to the screens and drawers this
  // one opens so amount entry and history continue in the same unit. Hidden
  // counts as sats — entering an amount while hidden isn't meaningful.
  bool get _fiatMode => _balanceDisplay == BalanceDisplay.fiat;

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
    _trackRecovery();
    _fetchExpirationStatus();
    _federationName = widget.federationName;
    // Fall back to reading the name off the client when the caller didn't
    // supply it (e.g. after a recovery or successor join).
    if (_federationName == null) {
      widget.client.federationName().then((name) {
        if (mounted) setState(() => _federationName = name);
      });
    }
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

  /// Surfaces a background recovery on the selector row. Only reached when the
  /// wallet was opened despite pending recoveries because every module stays
  /// usable (see `_replaceWithFederation`); a blocking recovery never gets here.
  void _trackRecovery() {
    if (!widget.client.hasPendingRecoveries()) return;

    setState(() => _recovering = true);

    _recoverySubscription = widget.client.subscribeRecoveryProgress().listen((
      percent,
    ) {
      if (mounted) setState(() => _recoveryPercent = percent);
    });

    // The modules stay usable, so no reopen is needed — just drop the indicator
    // once every recovery lands and the balance stream has caught up.
    widget.client.waitForAllRecoveries().then((_) {
      if (mounted) setState(() => _recovering = false);
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _recoverySubscription?.cancel();
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
    _handleInput(uri.toString());
  }

  Future<void> _handlePaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);

    if (!mounted) return;

    final input = data?.text?.trim();

    if (input == null || input.isEmpty) {
      NotificationUtils.showError(context, 'Clipboard is empty');
      return;
    }

    if (!_handleInput(input)) {
      NotificationUtils.showError(context, 'Unrecognized clipboard content');
    }
  }

  /// Routes a scanned/pasted/deep-linked string to the matching flow. Returns
  /// whether anything recognised it.
  bool _handleInput(String input) {
    final parsers = [
      (
        parseInviteCode(invite: input),
        (dynamic result) => InviteDrawer.show(
          context,
          invite: result,
          onJoin: _handleJoinFederation,
          onRecover: _handleRecoverFederation,
        ),
      ),
      (
        parseBolt11Invoice(invoice: input),
        (dynamic result) => LightningSendDrawer.show(
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
                (_) => OnchainAmountScreen(
                  client: widget.client,
                  address: result,
                  fiat: _fiatMode,
                ),
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
          fiat: _fiatMode,
        ),
      ),
    ];

    for (final (result, showDrawer) in parsers) {
      if (result != null) {
        showDrawer(result);
        return true;
      }
    }

    return false;
  }

  Future<void> _onReceiveLightning() async {
    final lnurl = await widget.client.lnurl();
    final currencyCode = widget.client.currencyCode();

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => DisplayLnurlScreen(
              client: widget.client,
              lnurl: lnurl,
              currencyCode: currencyCode,
              fiat: _fiatMode,
            ),
      ),
    );
  }

  Future<void> _onSendEcash() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EcashAmountScreen(
          client: widget.client,
          fiat: _fiatMode,
        ),
      ),
    );
  }

  Future<void> _onReceiveBitcoin() async {
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
              fiat: _fiatMode,
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
              fiat: _fiatMode,
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
          successor != null ? 'Tap to add successor' : 'Migrate your funds',
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

    _replaceWithFederation(client);
  }

  /// Replaces this screen with one for [client], routing through the recovery
  /// drawer when it has pending recoveries. [name] seeds the switcher row so it
  /// renders without waiting on `federationName()`.
  void _replaceWithFederation(ConduitClient client, {String? name}) {
    // Only block on the recovery drawer when a module can't be used until the
    // recovery finishes. When every module stays usable mid-recovery (e.g.
    // mintv2/walletv2), open the wallet straight away and surface progress on
    // the federation selector row instead.
    if (client.hasPendingRecoveries() && !client.allModulesUsable()) {
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
                federationName: name,
              ),
        ),
      );
    }
  }

  void _onSettings() {
    SettingsDrawer.show(
      context,
      client: widget.client,
      clientFactory: widget.clientFactory,
      onSelectRecovery: _openRecoveryPhrase,
      onSelectCurrency: _openCurrency,
      onSelectConnection: _openConnection,
      onSelectRemove: _openRemove,
    );
  }

  Future<void> _openCurrency() async {
    final currencyBefore = widget.client.currencyCode();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => SelectCurrencyScreen(clientFactory: widget.clientFactory),
      ),
    );

    if (!mounted) return;

    // The client caches the currency, so apply the change to the live client
    // and refresh its rate — no need to rebuild the client.
    final currencyAfter = await widget.clientFactory.getCurrency();

    if (!mounted || currencyAfter == currencyBefore) return;

    await widget.client.setCurrency(currencyCode: currencyAfter);

    if (!mounted) return;

    await widget.client.prefetchExchangeRates();

    if (mounted) setState(() {});
  }

  Future<void> _openRecoveryPhrase() async {
    try {
      await requireBiometricAuth(context);

      if (!mounted) return;

      final seedPhrase = await widget.clientFactory.seedPhrase();

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DisplayRecoveryPhraseScreen(seedPhrase: seedPhrase),
        ),
      );
    } catch (e) {
      if (mounted) NotificationUtils.showError(context, e.toString());
    }
  }

  void _openConnection() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConnectionStatusScreen(client: widget.client),
      ),
    );
  }

  void _openRemove() {
    RemoveFederationDrawer.show(
      context,
      client: widget.client,
      clientFactory: widget.clientFactory,
      onSuccess: _routeAfterRemove,
    );
  }

  // The federation is gone; drop the whole stack and let the home router open
  // whatever remains (another federation, or onboarding when none are left).
  void _routeAfterRemove() {
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => BaseScreen(clientFactory: widget.clientFactory),
      ),
      (route) => false,
    );
  }

  void _showFederationSwitcher() {
    SelectFederationDrawer.show(
      context,
      clientFactory: widget.clientFactory,
      onSelect: _switchFederation,
    );
  }

  /// Tears down the current client and opens the selected federation in its
  /// place, so the balance and payment history follow the switch.
  Future<void> _switchFederation(FederationInfo federation) async {
    try {
      final client = await widget.clientFactory.load(
        federationId: federation.id,
      );

      if (!mounted) {
        client?.shutdown();
        return;
      }

      if (client == null) {
        NotificationUtils.showError(context, 'Failed to load mint');
        return;
      }

      _replaceWithFederation(client, name: federation.name);
    } catch (e) {
      if (mounted) NotificationUtils.showError(context, e.toString());
    }
  }

  Future<void> _handleJoinFederation(InviteCodeWrapper invite) async {
    final client = await widget.clientFactory.join(invite: invite);

    if (!mounted) return;

    _openSuccessor(client);
  }

  Future<void> _handleRecoverFederation(InviteCodeWrapper invite) async {
    final client = await widget.clientFactory.recover(invite: invite);

    if (!mounted) return;

    _openSuccessor(client);
  }

  Widget _buildFederationSelector() {
    return StreamBuilder<List<(String, bool)>>(
      stream: _connectionStream,
      builder: (context, snapshot) {
        // While a background recovery runs, the row reports its progress
        // instead of connection health. The StreamBuilder stays mounted
        // (rather than being swapped out) so the connection status is already
        // resolved when recovery ends and the row doesn't flicker on handoff.
        if (_recovering) return _buildRecoveringSelector();

        // Tint the wallet icon amber and read "Offline" while too few guardians
        // are online to reach fedimint's consensus threshold (n - ⌊(n-1)/3⌋),
        // so a degraded federation is visible on the home screen without an
        // app-bar icon.
        Color? iconColor;
        String? subtitle;
        if (snapshot.hasData) {
          final statuses = snapshot.data!;
          final online = statuses.where((s) => s.$2).length;
          final threshold = statuses.length - ((statuses.length - 1) ~/ 3);
          final operational = online >= threshold;
          if (!operational) iconColor = Colors.amber;
          subtitle = operational ? 'Online' : 'Offline';
        }
        return SettingsCard(
          icon: PhosphorIconsRegular.wallet,
          iconColor: iconColor,
          title: _federationName ?? '',
          subtitle: subtitle,
          onTap: _showFederationSwitcher,
        );
      },
    );
  }

  /// The selector row during a background recovery: the federation name with a
  /// trailing spinner, and a "Recovering funds · X%" progress subtitle.
  Widget _buildRecoveringSelector() {
    final subColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final subtitle =
        _recoveryPercent == null
            ? 'Recovering'
            : 'Recovering · $_recoveryPercent%';

    return ListTile(
      contentPadding: listTilePadding,
      leading: const IconChip(icon: PhosphorIconsRegular.wallet),
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_federationName ?? '', style: mediumStyle),
              const SizedBox(width: 8),
              smallSpinner,
            ],
          ),
          Text(subtitle, style: smallStyle.copyWith(color: subColor)),
        ],
      ),
      onTap: _showFederationSwitcher,
    );
  }

  Future<void> _onScan() async {
    ScannerDrawer.show(
      context,
      client: widget.client,
      clientFactory: widget.clientFactory,
      onJoin: _handleJoinFederation,
      onRecover: _handleRecoverFederation,
      fiat: _fiatMode,
    );
  }

  void _showEventDetails(ConduitPayment event) {
    PaymentDetailsDrawer.show(context, event: event, client: widget.client);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.gearSix, size: smallIconSize),
          onPressed: _onSettings,
        ),
        actions: [
          IconButton(
            icon: const Icon(
              PhosphorIconsRegular.clipboardText,
              size: smallIconSize,
            ),
            onPressed: _handlePaste,
          ),
          IconButton(
            icon: const Icon(PhosphorIconsRegular.at, size: smallIconSize),
            onPressed: _onLightningAddress,
          ),
          IconButton(
            icon: const Icon(PhosphorIconsRegular.users, size: smallIconSize),
            onPressed: _onContacts,
          ),
        ],
      ),
      body: AmountDisplay(
        display: _balanceDisplay,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
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
                          sats: snapshot.data,
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
              _buildFederationSelector(),
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
                  // Each button gets an equal share of the row, so the four
                  // actions can never overflow the screen width.
                  child: Row(
                    children: [
                      Expanded(
                        child: CircularActionButton(
                          icon: PhosphorIconsRegular.lightning,
                          label: 'Lightning',
                          onTap: _onReceiveLightning,
                        ),
                      ),
                      Expanded(
                        child: CircularActionButton(
                          icon: PhosphorIconsRegular.link,
                          label: 'Onchain',
                          onTap: _onReceiveBitcoin,
                        ),
                      ),
                      Expanded(
                        child: CircularActionButton(
                          icon: PhosphorIconsRegular.coinVertical,
                          label: 'eCash',
                          onTap: _onSendEcash,
                        ),
                      ),
                      Expanded(
                        child: CircularActionButton(
                          icon: PhosphorIconsRegular.qrCode,
                          label: 'Scan',
                          onTap: _onScan,
                        ),
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
  // Null until the balance stream resolves, so AnimatedBalance can tell an
  // unresolved balance from a genuine 0 (see AnimatedBalance).
  final int? sats;
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
        display == BalanceDisplay.fiat
            ? cachedFiatAmount(client, sats ?? 0)
            : null;
    final hidden = display == BalanceDisplay.hidden;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // Stretch to full width so the centered text aligns to the screen
        // centre rather than shrink-wrapping the number.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hidden masks the amount with the same dots used for payment-row
          // amounts, keeping the " sat" suffix and layout in place.
          //
          // Scale down so short balances render at the full amountStyle size and
          // long ones shrink to fit the width on one line.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: hidden
                  ? Text.rich(
                      textAlign: TextAlign.center,
                      const TextSpan(
                        children: [
                          TextSpan(text: maskedAmount, style: amountStyle),
                          TextSpan(text: ' sat', style: amountUnitStyle),
                        ],
                      ),
                    )
                  : fiat != null
                  ? AnimatedBalance(
                      sats: sats,
                      style: amountStyle,
                      textAlign: TextAlign.center,
                      // Convert each tweened sats value to fiat so it counts up
                      // on the same tween as the sats view.
                      formatter: (s) => cachedFiatAmount(client, s)?.amount ?? '',
                    )
                  : AnimatedBalance(
                      sats: sats,
                      style: amountStyle,
                      unitStyle: amountUnitStyle,
                      textAlign: TextAlign.center,
                    ),
            ),
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
