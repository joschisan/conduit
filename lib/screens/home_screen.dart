import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:conduit/bridge_generated.dart/account.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/events.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/lnurl.dart';
import 'package:conduit/drawers/ecash_drawer.dart';
import 'package:conduit/drawers/invite_drawer.dart';
import 'package:conduit/drawers/lightning_send_drawer.dart';
import 'package:conduit/drawers/lnurl_drawer.dart';
import 'package:conduit/drawers/payment_details_drawer.dart';
import 'package:conduit/drawers/recovery_drawer.dart';
import 'package:conduit/drawers/remove_federation_drawer.dart';
import 'package:conduit/drawers/scanner_drawer.dart';
import 'package:conduit/drawers/select_account_drawer.dart';
import 'package:conduit/drawers/select_page_drawer.dart';
import 'package:conduit/drawers/settings_drawer.dart';
import 'package:conduit/screens/connection_status_screen.dart';
import 'package:conduit/screens/display_contacts_screen.dart';
import 'package:conduit/screens/display_lnurl_screen.dart';
import 'package:conduit/screens/display_recovery_phrase_screen.dart';
import 'package:conduit/screens/ecash_amount_screen.dart';
import 'package:conduit/screens/lightning_address_entry_screen.dart';
import 'package:conduit/screens/onchain_address_screen.dart';
import 'package:conduit/screens/onchain_amount_screen.dart';
import 'package:conduit/screens/select_currency_screen.dart';
import 'package:conduit/screens/wallet_v2_receive_screen.dart';
import 'package:conduit/utils/account_utils.dart';
import 'package:conduit/utils/auth_utils.dart';
import 'package:conduit/utils/currency_utils.dart';
import 'package:conduit/utils/notification_utils.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/widgets/amount_visibility.dart';
import 'package:conduit/widgets/animated_balance_widget.dart';
import 'package:conduit/widgets/animated_entry_widget.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/circular_action_button_widget.dart';
import 'package:conduit/widgets/icon_chip_widget.dart';
import 'package:conduit/widgets/recent_payments_widget.dart';
import 'package:conduit/widgets/settings_card_widget.dart';

/// How the pager slides onto a page it was sent to rather than swiped to.
/// Long enough to read as travel across the pages in between — which is the
/// point of animating it — and eased so it drifts to a stop instead of
/// snapping: the move wasn't a flick, so it shouldn't land like one.
const _pageSlideDuration = Duration(milliseconds: 500);
const _pageSlideCurve = Curves.easeInOutSine;

/// Identifies one `(mint, account)` client. A mint id alone no longer does: a
/// mint contributes one client per account, and the pager swipes through all
/// of them.
String _clientKey(ConduitClient client) =>
    '${client.federationIdHex()}/${client.account().name}';

/// Multimint home: the balance and the row naming its account form one
/// swipeable page, so every balance is paged through rather than picked from
/// a list. Each mint has five accounts — the mint cannot tell them apart; they
/// exist only to keep money in separate piles — but only the ones worth
/// showing get pages, so a swipe crosses whichever accounts are in use and
/// then on to the next mint. The page you land on is the balance every action
/// spends from. The leading gear opens the settings drawer, which is where the
/// account picker and removing a mint live.
///
/// Every client stays open for as long as its mint is added, so each page's
/// balance is live whether or not it is in view, and switching is a change of
/// view rather than a teardown.
///
/// Always has a mint: it is only ever mounted with one — from startup or from
/// [BaseScreen] — and the last one can't be removed, so nothing comes back
/// here short of a restart with an empty wallet.
class HomeScreen extends StatefulWidget {
  final ConduitClientFactory clientFactory;
  final List<ConduitClient> initialClients;
  // The account the wallet was left on, to open on again. Null from
  // onboarding, where the first page is the only one there is.
  final ConduitClient? initialSelected;

  const HomeScreen({
    super.key,
    required this.clientFactory,
    required this.initialClients,
    this.initialSelected,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<List<ConduitClient>>? _clientsSubscription;

  // Never empty: seeded from the mount-time list and only ever replaced by a
  // non-empty emission. Every account of every added mint, shown or not —
  // [_visible] is the subset with pages.
  late List<ConduitClient> _clients = widget.initialClients;
  // The accounts the pager carries, in [_clients] order. Derived state, kept
  // in a field rather than recomputed in `build` because the pager indexes
  // into it: the selection is a position in this list, so it has to hold
  // still between the frame that changes it and the jump that follows.
  late List<ConduitClient> _visible = _computeVisible();
  // Accounts opened from the picker this session. Not persisted as a set: an
  // empty account you opened once would otherwise keep its page for good,
  // and anything you actually put money into keeps its page on its own. The
  // one exception is the account the wallet was left on, which gets its page
  // back so the launch lands where the last one ended.
  late final Set<String> _opened = {
    if (widget.initialSelected case final selected?) _clientKey(selected),
  };
  // Mints seen in the last emission, so the next one can tell an arrival.
  late Set<String> _knownMintIds =
      _clients.map((c) => c.federationIdHex()).toSet();
  // Holds the selection, not just the scroll: the account in view is the one
  // every action routes through, so this controller is the only place it is
  // recorded in memory. Starts on the account the wallet was left on, else
  // the first mint's first account.
  late final PageController _pageController = PageController(
    initialPage: _initialPage(),
  );

  int _initialPage() {
    final selected = widget.initialSelected;
    if (selected == null) return 0;

    final index = _visible.indexWhere(
      (c) => _clientKey(c) == _clientKey(selected),
    );
    return index < 0 ? 0 : index;
  }

  // One session per account: this is where an account's streams are listened
  // to, so everything below is a pure function of the values they carry.
  // Keyed by [_clientKey] and kept in step with [_clients] by [_syncSessions],
  // so a client in that list always has an entry here.
  final Map<String, _AccountSession> _sessions = {};
  // One per mint, shared by every account page of that mint — connectivity
  // and expiry are mint-wide state, so five pages carry one stream instead of
  // one each. Keyed by the federation id's hex form.
  final Map<String, _MintSession> _mints = {};
  // Mints whose recovery drawer is up, so a set change mid-recovery doesn't
  // stack a second one.
  final Set<String> _recoveryDrawers = {};
  // Single cycling control over how balances read: sats → fiat → hidden.
  // Starts hidden so balances aren't exposed on open.
  BalanceDisplay _balanceDisplay = BalanceDisplay.hidden;

  // Whether the balance is showing fiat, passed to the screens and drawers
  // this one opens so amount entry and history continue in the same unit.
  // Hidden counts as sats — entering an amount while hidden isn't meaningful.
  bool get _fiatMode => _balanceDisplay == BalanceDisplay.fiat;

  // Whether a cached exchange rate exists, so the fiat step is reachable.
  // `satsToFiat` is a cache-only sync read returning null when no fresh rate
  // is stored; the cache is shared, so any client answers for all.
  bool get _fiatAvailable => _clients.first.satsToFiat(amountSats: 0) != null;

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
    _syncSessions(_clients);
    _clientsSubscription = widget.clientFactory.subscribeClients().listen((
      clients,
    ) {
      if (!mounted) return;
      // Unreachable while the last mint can't be removed, and kept so a
      // future path to an empty wallet degrades to a stale row rather than a
      // crash on `_clients.first`.
      if (clients.isEmpty) return;
      setState(() {
        _clients = clients;
        final ids = clients.map((c) => c.federationIdHex()).toSet();
        // A mint that wasn't in the previous list was just added, so page to
        // it — the user acted on it, and an add that restored funds arrives
        // with them already on its balances. Its first page is its first
        // account, since the list orders by mint then account. A mint that
        // was removed needs no counterpart: the pager clamps onto a page that
        // still exists, and whatever it lands on is the selection.
        final arrived = ids.difference(_knownMintIds);
        _knownMintIds = ids;
        _syncSessions(clients);
        // A mint that was removed takes its accounts with it, so a re-add
        // later in the same session starts from a fresh primary.
        final live = clients.map(_clientKey).toSet();
        _opened.removeWhere((key) => !live.contains(key));
        _visible = _computeVisible();

        if (arrived.isNotEmpty) {
          _pageTo(
            _visible.indexWhere((c) => arrived.contains(c.federationIdHex())),
            animate: true,
          );
        }
      });
      _showBlockingRecoveries();
    });
    // Warm the exchange-rate cache so the fiat balance toggle and the
    // send/receive fiat rows render from cache without blocking. Repaint once
    // the rate lands so a balance shown in fiat updates from its sats
    // fallback without waiting for the next balance change.
    _clients.first.prefetchExchangeRates().then((_) {
      if (mounted) setState(() {});
    });
    _initDeepLinks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showBlockingRecoveries();
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _clientsSubscription?.cancel();
    _pageController.dispose();
    for (final session in _sessions.values) {
      session.dispose();
    }
    for (final session in _mints.values) {
      session.dispose();
    }
    super.dispose();
  }

  /// A mint whose recovery holds a module out of the registry can't be used
  /// until the recovery lands and its clients are reopened; the drawer waits
  /// for that and reopens them. A recovery every module stays usable through
  /// needs no drawer — the page shows its progress on the mint row instead.
  void _showBlockingRecoveries() {
    if (!mounted) return;

    for (final mintId in _knownMintIds) {
      final clients =
          _clients.where((c) => c.federationIdHex() == mintId).toList();
      final blocking = clients.any(
        (c) => c.hasPendingRecoveries() && !c.allModulesUsable(),
      );

      if (!blocking) {
        _recoveryDrawers.remove(mintId);
        continue;
      }

      if (!_recoveryDrawers.add(mintId)) continue;

      RecoveryDrawer.show(
        context,
        clients: clients,
        clientFactory: widget.clientFactory,
      );
    }
  }

  /// Arriving funds already announce themselves: the payment row grows in
  /// and the balance counts up. A haptic is the only extra signal — no toast
  /// for an outcome the screen is showing. A failure gets both.
  void _handleNotification(PaymentNotification notification) {
    if (!mounted) return;

    HapticFeedback.heavyImpact();

    if (notification.success) return;

    NotificationUtils.showError(
      context,
      notification.incoming
          ? 'Failed to receive payment'
          : 'Failed to send payment',
    );
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    _linkSubscription = _appLinks.uriLinkStream.listen(_handleDeepLink);

    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) => _handleInput(uri.toString());

  /// The app-bar counterpart to the scanner: same inputs, same flows, without
  /// opening the camera for a code that is already on the clipboard.
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

  /// Routes a scanned/pasted/deep-linked string to the matching flow, against
  /// the account in view. Returns whether anything recognised it.
  bool _handleInput(String input) {
    final client = _selectedClient();

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
        (dynamic result) =>
            LightningSendDrawer.show(context, client: client, invoice: result),
      ),
      (
        parseEcash(notes: input),
        (dynamic result) =>
            EcashDrawer.show(context, client: client, notes: result),
      ),
      (
        parseBitcoinAddress(address: input),
        (dynamic result) => Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) => OnchainAmountScreen(
                  client: client,
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
          client: client,
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

  /// The account in view — a mint and one of its five balances — and so the
  /// account every action routes through.
  ///
  /// Read from the pager rather than mirrored into state. A selection kept in
  /// both places has to be reconciled every time either moves — and the pager
  /// moves on its own, clamping itself when the list shrinks under it, so the
  /// mirror is the copy that goes stale.
  ///
  /// Rounds mid-drag to the page the swipe is committing to, which is the one
  /// the user is looking at. Before the first layout there is no position to
  /// read and the pager sits on its initial page; the clamp covers the frame
  /// between a mint being removed — taking its pages with it — and the pager
  /// laying out over the shorter list.
  ConduitClient _selectedClient() {
    final page = _pageController.hasClients ? _pageController.page : null;
    final index = (page ?? _pageController.initialPage.toDouble()).round();

    return _visible[index.clamp(0, _visible.length - 1)];
  }

  /// Moves the pager onto [index], deferred a frame so it has rebuilt with
  /// the new page count first.
  ///
  /// Jumps by default: the move is bookkeeping — holding the selection as
  /// pages shift around it — and should not read as navigation. Animates when
  /// the move is the point: a mint just added, a page just opened, a balance
  /// that just moved, where sliding over to the page shows where it landed
  /// among the others instead of teleporting onto it.
  void _pageTo(int index, {bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;

      if (animate) {
        _pageController.animateToPage(
          index,
          duration: _pageSlideDuration,
          curve: _pageSlideCurve,
        );
      } else {
        _pageController.jumpToPage(index);
      }
    });
  }

  /// [_pageTo] by account rather than by position, for the callers that know
  /// which account they mean and would otherwise each look its index up. The
  /// account may have no page — a balance can move in one the pager isn't
  /// carrying — in which case there is nowhere to slide to.
  void _pageToAccount(String key, {bool animate = false}) {
    final index = _visible.indexWhere((c) => _clientKey(c) == key);

    if (index >= 0) _pageTo(index, animate: animate);
  }

  /// Brings [_sessions] and [_mints] into step with the client set: a client
  /// that arrived gets its streams opened, one that went gets them closed,
  /// and one that was reopened — same account, new instance, after a
  /// recovery — is re-listened to, since the old client's streams ended
  /// with it. Called inside the same `setState` that swaps [_clients], so
  /// the two never disagree by the time anything builds.
  void _syncSessions(List<ConduitClient> clients) {
    for (final client in clients) {
      final mintId = client.federationIdHex();
      final mint = _mints[mintId];
      if (client.account() == Account.primary &&
          (mint == null || mint.instanceId != client.instanceId())) {
        mint?.dispose();
        final session = _MintSession(client);
        // The expiry card below the pager is built from this, and lands
        // after a round trip, so it is the one mint-wide value that has to
        // rebuild the screen rather than a widget watching it.
        session.expiration.addListener(() {
          if (mounted) setState(() {});
        });
        _mints[mintId] = session;
      }

      final key = _clientKey(client);
      final existing = _sessions[key];
      if (existing != null) {
        if (existing.client.instanceId() == client.instanceId()) continue;
        existing.dispose();
      }

      final session = _AccountSession(
        client,
        onNotification: _handleNotification,
      );
      // The balance as it stood the last time the listener below ran, so the
      // first value can be told from the ones after it: the first is the
      // account being read, and only a move past it is money arriving or
      // leaving.
      int? previous;
      // Money earns the account its page: the balance going positive adds it
      // to [_opened] rather than being read live by [_isVisible], so a max
      // send that empties the account leaves the page standing at zero
      // instead of yanking it out from under the user mid-flow. On restart
      // the balance decides afresh. The listener goes with the session when
      // it is disposed.
      session.balance.addListener(() {
        final sats = session.balance.value;
        if (sats == null) return;
        final moved = previous != null && sats != previous;
        previous = sats;
        if (sats > 0) _opened.add(key);
        _refreshVisible();
        // A balance that moved is the one worth looking at, so its page comes
        // into view on the same slide the picker gives it. Registered after
        // the jump [_refreshVisible] may have queued, so an account that just
        // earned its page slides over from where the user was rather than
        // being landed on.
        if (moved) _pageToAccount(key, animate: true);
      });
      _sessions[key] = session;
    }

    final keys = clients.map(_clientKey).toSet();
    for (final key in _sessions.keys.toList()) {
      if (!keys.contains(key)) _sessions.remove(key)!.dispose();
    }

    final mints = clients.map((c) => c.federationIdHex()).toSet();
    for (final key in _mints.keys.toList()) {
      if (!mints.contains(key)) _mints.remove(key)!.dispose();
    }
  }

  /// Whether [client] gets a page.
  ///
  /// Five accounts each is more pages than a wallet with two mints wants to
  /// swipe through when it is using one of them, so an account earns its page
  /// rather than being given one. Primary always has one — it is where an add
  /// lands. The rest earned theirs into [_opened], by being opened from the
  /// picker or by money turning up in them: a balance is never hidden, which
  /// is what makes a restore that finds funds in an account nobody ever
  /// opened surface them instead of swallowing them. Either way the page is
  /// held for the session — spending the account empty doesn't take it.
  bool _isVisible(ConduitClient client) {
    if (client.account() == Account.primary) return true;

    return _opened.contains(_clientKey(client));
  }

  List<ConduitClient> _computeVisible() {
    final visible = _clients.where(_isVisible).toList();

    // Unreachable — every mint contributes a primary — and kept so a pager
    // with no pages can never be built.
    return visible.isEmpty ? _clients : visible;
  }

  /// Recomputes which accounts have pages, rebuilding only when the answer
  /// changed. Called whenever one of its three inputs moves: the client set,
  /// the opened set, and any account's balance.
  ///
  /// Holds the selection across the change. The pager indexes into
  /// [_visible], so a page appearing ahead of the current one would otherwise
  /// slide the selection sideways under a user who did nothing — and the
  /// selection is what every action spends from.
  void _refreshVisible() {
    if (!mounted) return;

    final next = _computeVisible();
    final keys = next.map(_clientKey).toList();

    if (listEquals(keys, _visible.map(_clientKey).toList())) return;

    final selected = _clientKey(_selectedClient());

    setState(() => _visible = next);

    final index = keys.indexOf(selected);

    // The page in view is one that just went — pages are held for the
    // session, so only its mint being removed takes it. Its mint's primary is
    // the nearest page to it, and when that was removed too, the fallback
    // lands on the first page.
    _pageTo(index >= 0 ? index : _primaryIndexOf(selected, next));
  }

  /// Where [key]'s mint keeps its primary in [clients].
  int _primaryIndexOf(String key, List<ConduitClient> clients) {
    final mintId = key.split('/').first;
    final index = clients.indexWhere(
      (c) => c.federationIdHex() == mintId && c.account() == Account.primary,
    );
    return index < 0 ? 0 : index;
  }

  Future<void> _onReceiveLightning() async {
    final client = _selectedClient();
    final lnurl = await client.lnurl();
    final currencyCode = client.currencyCode();

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => DisplayLnurlScreen(
              client: client,
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
        builder:
            (_) =>
                EcashAmountScreen(client: _selectedClient(), fiat: _fiatMode),
      ),
    );
  }

  Future<void> _onReceiveBitcoin() async {
    final client = _selectedClient();

    try {
      final v2Address = await client.walletV2Receive();

      if (!mounted) return;

      if (v2Address != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) =>
                    WalletV2ReceiveScreen(address: v2Address, client: client),
          ),
        );
      } else {
        // Addresses already sorted ascending by Rust (oldest first, newest
        // last)
        final addressesList = await client.onchainListAddresses();

        if (!mounted) return;

        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (context) => OnchainAddressScreen(
                  client: client,
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
              client: _selectedClient(),
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
              client: _selectedClient(),
              clientFactory: widget.clientFactory,
              fiat: _fiatMode,
            ),
      ),
    );
  }

  Future<void> _onScan() async {
    ScannerDrawer.show(
      context,
      client: _selectedClient(),
      clientFactory: widget.clientFactory,
      onJoin: _handleJoinFederation,
      onRecover: _handleRecoverFederation,
      fiat: _fiatMode,
    );
  }

  /// Adds the mint and closes the invite drawer that confirmed it. Nothing to
  /// route: the client stream brings the new mint's pages, and the pager
  /// slides onto them.
  Future<void> _handleJoinFederation(InviteCodeWrapper invite) async {
    await widget.clientFactory.join(invite: invite);

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleRecoverFederation(InviteCodeWrapper invite) async {
    await widget.clientFactory.recover(invite: invite);

    if (mounted) Navigator.of(context).pop();
  }

  void _onSettings() {
    SettingsDrawer.show(
      context,
      client: _selectedClient(),
      clientFactory: widget.clientFactory,
      onSelectRecovery: _openRecoveryPhrase,
      onSelectCurrency: _openCurrency,
      onSelectAccount: _openSelectAccount,
      onSelectConnection: _openConnection,
      // Removing the last mint would strand the wallet on onboarding, so the
      // row only appears once there is another to fall back to.
      onSelectRemove: _knownMintIds.length > 1 ? _openRemove : null,
    );
  }

  /// Lists the selected mint's accounts, including the ones without pages —
  /// this is the only place they can be reached from.
  void _openSelectAccount() {
    final mintId = _selectedClient().federationIdHex();
    SelectAccountDrawer.show(
      context,
      accounts: [
        for (final client in _clients)
          if (client.federationIdHex() == mintId)
            (client: client, balance: _sessions[_clientKey(client)]!.balance),
      ],
      onSelect: _selectAccount,
      display: _balanceDisplay,
    );
  }

  /// Gives [client] a page if it hasn't got one and swipes to it. Choosing an
  /// account is how an empty one is brought out — it holds its page for as
  /// long as the app is up, and past that only if it has a balance.
  void _selectAccount(ConduitClient client) {
    _opened.add(_clientKey(client));
    _refreshVisible();
    // Registered after the jump [_refreshVisible] may have queued, so the
    // slide starts from the page that was in view rather than from wherever
    // the new page pushed it.
    _pageToAccount(_clientKey(client), animate: true);
  }

  /// Lists every page the pager carries, across mints, and swipes to the one
  /// chosen. Opened from the row naming the page in view: at three mints the
  /// balance you want is several swipes away, and this is the swipe as a
  /// list. Adds no pages of its own — that is [_openSelectAccount]'s job.
  void _openSelectPage() {
    SelectPageDrawer.show(
      context,
      pages: [
        for (final client in _visible)
          (client: client, balance: _sessions[_clientKey(client)]!.balance),
      ],
      selectedKey: _clientKey(_selectedClient()),
      keyOf: _clientKey,
      onSelect: _selectPage,
      display: _balanceDisplay,
    );
  }

  /// Swipes to [client]'s page. It already has one — the picker only lists
  /// pages — so there is nothing to make visible first.
  void _selectPage(ConduitClient client) {
    _pageToAccount(_clientKey(client), animate: true);
  }

  Future<void> _openCurrency() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => SelectCurrencyScreen(clientFactory: widget.clientFactory),
      ),
    );

    if (!mounted) return;

    // The currency is shared by every client, so the factory has already
    // applied any change; refresh the rate and repaint off it.
    await _clients.first.prefetchExchangeRates();

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
        builder: (_) => ConnectionStatusScreen(client: _selectedClient()),
      ),
    );
  }

  void _openRemove() {
    RemoveFederationDrawer.show(
      context,
      client: _selectedClient(),
      clientFactory: widget.clientFactory,
      // Nothing to route: the client stream drives the selection, so the
      // pager and every action follow the remaining mints on their own.
      onSuccess: () {},
    );
  }

  void _showEventDetails(ConduitPayment event) {
    PaymentDetailsDrawer.show(context, event: event, client: _selectedClient());
  }

  Future<void> _joinSuccessor(InviteCodeWrapper invite) async {
    await widget.clientFactory.join(invite: invite);

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _recoverSuccessor(InviteCodeWrapper invite) async {
    await widget.clientFactory.recover(invite: invite);

    if (mounted) Navigator.of(context).pop();
  }

  /// The expiry notice for the mint in view, when it has one. Below the
  /// pager rather than on the page: it is the mint's, not the account's, and
  /// it leads to adding a successor, which is an action like the ones under
  /// it.
  Widget? _buildExpiryCard() {
    final mint = _mints[_selectedClient().federationIdHex()];
    final date = mint?.expirationDate;

    if (mint == null || date == null) return null;

    final formatted = DateFormat.MMMMd().format(
      DateTime.fromMillisecondsSinceEpoch(date * 1000),
    );
    final successor = mint.expirationSuccessor;

    return BorderedList.column(
      children: [
        SettingsCard(
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
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedClient();
    final expiry = _buildExpiryCard();

    return Scaffold(
      appBar: AppBar(
        // Settings leads, so the actions on the right are all things to do
        // with a payment: paste one, address one, pick who it's for.
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Leads the block: the only affordance that it swipes, and
              // above the balance it reads as a header for what follows
              // rather than a footnote under the account row. Kept at a
              // single account too, so the balance block sits at the same
              // height however many accounts there are.
              _PageDots(count: _visible.length, controller: _pageController),
              _MintPager(
                clients: _visible,
                sessions: _sessions,
                mints: _mints,
                controller: _pageController,
                display: _balanceDisplay,
                onBalanceTap: _cycleBalanceDisplay,
                onAccountTap: _openSelectPage,
                // Settling on a page is the selection being made — the same
                // commitment a tap in a picker would have been, so it gets
                // the same haptic, and it is remembered for the next launch.
                // The rows below the pager follow the selection, so they
                // rebuild here.
                onPageChanged: (index) {
                  HapticFeedback.selectionClick();
                  final client = _visible[index.clamp(0, _visible.length - 1)];
                  widget.clientFactory.setSelected(
                    federationId: client.federationId(),
                    account: client.account(),
                  );
                  setState(() {});
                },
              ),
              // Grows in under the pager the way a new payment row does,
              // whether the date landed just now or a swipe brought an
              // expiring mint into view, rather than shoving the actions
              // down in one frame. Keyed by mint so the next expiring mint
              // grows its own card rather than inheriting this one's.
              if (expiry != null)
                AnimatedEntry(
                  key: ValueKey(selected.federationIdHex()),
                  child: expiry,
                ),
              // The gap the actions keep from whatever row is above them,
              // card or not, as the selector row kept it before the pager.
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
              // Keyed by the selection so a page change starts the list
              // afresh: its rows are the account in view's, and the entry
              // animation is for payments that arrive, not for a swipe.
              // The swap itself cross-fades at the pager's pace, so what
              // sits under the balance follows the swipe instead of
              // snapping the moment the page commits.
              AnimatedSwitcher(
                duration: _pageSlideDuration,
                switchInCurve: _pageSlideCurve,
                switchOutCurve: _pageSlideCurve,
                // Both lists keep the column's full width and hang from the
                // top while they overlap, rather than the default centring,
                // which would float the shorter one mid-block.
                layoutBuilder:
                    (current, previous) => Stack(
                      alignment: Alignment.topCenter,
                      fit: StackFit.passthrough,
                      children: [...previous, if (current != null) current],
                    ),
                child: RecentPayments(
                  key: ValueKey(_clientKey(selected)),
                  client: selected,
                  payments: _sessions[_clientKey(selected)]!.payments,
                  onTransactionTap: _showEventDetails,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The UI's half of one account: its balance and event log streams, listened
/// to once and held open for as long as that account's client is. Held by
/// [_HomeScreenState._sessions], one per open `(mint, account)` client.
///
/// The bridge hands back a single-subscription stream per call, so a stream
/// passed down the tree would throw the second time a widget listened to it.
/// Listening here instead turns it into a value that any number of widgets
/// can read, rebuild from, and stop reading without consequence — which is
/// what lets every page below be stateless.
class _AccountSession {
  final ConduitClient client;
  // Null until the first value lands: an unresolved balance is not a zero
  // one.
  final ValueNotifier<int?> balance = ValueNotifier(null);
  final ValueNotifier<List<ConduitPayment>> payments = ValueNotifier([]);
  // Set while a background recovery runs on a client that is already usable
  // (its modules stay in the registry mid-recovery). Drives the spinner and
  // "Recovering · X%" progress on the mint row. The percentage is the
  // minimum across every recovering module, computed on the Rust side.
  final ValueNotifier<bool> recovering = ValueNotifier(false);
  final ValueNotifier<int?> recoveryPercent = ValueNotifier(null);
  late final StreamSubscription<int> _balanceSubscription;
  late final StreamSubscription<RecentPaymentsUpdate> _eventSubscription;
  StreamSubscription<int>? _recoverySubscription;

  _AccountSession(
    this.client, {
    required void Function(PaymentNotification) onNotification,
  }) {
    _balanceSubscription = client.subscribeBalance().listen(
      (sats) => balance.value = sats,
    );
    _eventSubscription = client.subscribeEventLog().listen((update) {
      payments.value = update.payments;
      if (update.notification case final notification?) {
        onNotification(notification);
      }
    });
    _trackRecovery();
  }

  void _trackRecovery() {
    if (!client.hasPendingRecoveries()) return;

    recovering.value = true;

    _recoverySubscription = client.subscribeRecoveryProgress().listen(
      (percent) => recoveryPercent.value = percent,
    );

    // The modules stay usable, so no reopen is needed — just drop the
    // indicator once every recovery lands and the balance stream has caught
    // up. A blocking recovery is reopened by the recovery drawer instead, and
    // this session goes with the old client.
    client.waitForAllRecoveries().then((_) => recovering.value = false);
  }

  void dispose() {
    _balanceSubscription.cancel();
    _eventSubscription.cancel();
    _recoverySubscription?.cancel();
    balance.dispose();
    payments.dispose();
    recovering.dispose();
    recoveryPercent.dispose();
  }
}

/// One mint's connectivity and expiry, shared by every account page of that
/// mint and read from its Primary client. Null until the first snapshot
/// lands: no status yet is not "offline".
class _MintSession {
  /// Which open of Primary this was built from, so a reopen after recovery
  /// is told apart from a re-listing and re-listened to.
  final BigInt instanceId;
  final ValueNotifier<List<(String, bool)>?> connectivity = ValueNotifier(null);
  final ValueNotifier<int?> _expiration = ValueNotifier(null);
  int? expirationDate;
  InviteCodeWrapper? expirationSuccessor;
  late final StreamSubscription<List<(String, bool)>> _subscription;

  /// Fires once the expiry has been read, so the card can appear.
  ValueListenable<int?> get expiration => _expiration;

  _MintSession(ConduitClient client) : instanceId = client.instanceId() {
    _subscription = client.subscribeConnectionStatus().listen(
      (statuses) => connectivity.value = statuses,
    );
    _fetchExpiration(client);
  }

  Future<void> _fetchExpiration(ConduitClient client) async {
    final date = await client.expirationDate();
    if (date == null) return;

    expirationSuccessor = await client.expirationSuccessor();
    expirationDate = date;
    _expiration.value = date;
  }

  void dispose() {
    _subscription.cancel();
    connectivity.dispose();
    _expiration.dispose();
  }
}

/// Hero balance shown above the mint row. Masked away when hidden, shown in
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

    // No gap of its own above the figure: the page dots carry the 16px
    // between them and it, which is the gap pico's headline sits under.
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // Stretch to full width so the centered text aligns to the screen
        // centre rather than shrink-wrapping the number.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hidden masks the amount with the same dots used for payment-row
          // amounts, keeping the " sat" suffix and layout in place.
          //
          // Scale down so short balances render at the full amountStyle size
          // and long ones shrink to fit the width on one line.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child:
                  hidden
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
                        // Convert each tweened sats value to fiat so it counts
                        // up on the same tween as the sats view.
                        formatter:
                            (s) => cachedFiatAmount(client, s)?.amount ?? '',
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

/// Names the account its page belongs to: a mint chip, the mint name as the
/// header and the account beneath. The balance lives in the hero above.
///
/// The account reads here because it is the half of the selection the mint
/// name doesn't state — swiping within a mint changes only this line, and it
/// is the only thing distinguishing five pages that otherwise look alike.
///
/// Connectivity keeps the chip: it tints amber while too few guardians are
/// online to reach fedimint's consensus threshold, so a degraded mint is
/// still flagged on the row it belongs to rather than from an app-bar icon.
/// The detail behind it is a tap away on the connection screen. While a
/// background recovery runs, the row reports its progress in the account's
/// place.
///
/// Tapping it opens the list of the pager's pages: the row names the page in
/// view, so it is where you would look to go to another one, and a list beats
/// a swipe once the balance you are after is several pages away.
class _MintRow extends StatelessWidget {
  final String name;
  final String account;
  final ValueListenable<List<(String, bool)>?> connectivity;
  final ValueListenable<bool> recovering;
  final ValueListenable<int?> recoveryPercent;
  final VoidCallback onTap;

  const _MintRow({
    required this.name,
    required this.account,
    required this.connectivity,
    required this.recovering,
    required this.recoveryPercent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: Listenable.merge([connectivity, recovering, recoveryPercent]),
      builder: (context, _) {
        // Untinted until the first snapshot lands, so amber only ever means
        // "too few guardians to sign" (n - ⌊(n-1)/3⌋).
        Color? iconColor;
        if (connectivity.value case final statuses?) {
          final online = statuses.where((s) => s.$2).length;
          final threshold = statuses.length - ((statuses.length - 1) ~/ 3);
          if (online < threshold) iconColor = Colors.amber;
        }

        final percent = recoveryPercent.value;
        final subtitle =
            recovering.value
                ? (percent == null ? 'Recovering' : 'Recovering · $percent%')
                : account;

        return ListTile(
          contentPadding: listTilePadding,
          onTap: onTap,
          leading: IconChip(
            icon: PhosphorIconsRegular.wallet,
            color: iconColor,
          ),
          // Both texts go in the title slot so ListTile sees a single-line
          // tile (56dp min) instead of the 72dp two-line tile a populated
          // `subtitle` would force. Keeps the row height consistent with the
          // other rows in the app.
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      style: mediumStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (recovering.value) ...[
                    const SizedBox(width: 8),
                    smallSpinner,
                  ],
                ],
              ),
              Text(
                subtitle,
                style: smallStyle.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One account's page: its balance over the row naming it, both read from
/// that account's [_AccountSession]. Stateless, so the pager is free to build
/// and drop pages as they scroll.
class _MintPage extends StatelessWidget {
  final ConduitClient client;
  final _AccountSession session;
  final _MintSession mint;
  final BalanceDisplay display;
  final VoidCallback onBalanceTap;
  final VoidCallback onAccountTap;

  const _MintPage({
    required this.client,
    required this.session,
    required this.mint,
    required this.display,
    required this.onBalanceTap,
    required this.onAccountTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The pager bleeds to the screen edges so pages slide edge to edge,
        // which leaves the hero to keep its own inset. The row below bleeds,
        // as list rows do.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          // Tapping the balance cycles the display, the same control as the
          // app-bar switcher.
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBalanceTap,
            child: ValueListenableBuilder<int?>(
              valueListenable: session.balance,
              builder:
                  (context, sats, _) => _BalanceHero(
                    sats: sats,
                    client: client,
                    display: display,
                  ),
            ),
          ),
        ),
        BorderedList.column(
          children: [
            _MintRow(
              name: client.federationName(),
              account: client.account().displayName,
              connectivity: mint.connectivity,
              recovering: session.recovering,
              recoveryPercent: session.recoveryPercent,
              onTap: onAccountTap,
            ),
          ],
        ),
      ],
    );
  }
}

/// One page per shown account — its balance over the row naming it — swiped
/// through to choose the account every action routes through. Ordered as the
/// client list is, so a mint's accounts sit together and swiping runs through
/// one mint before reaching the next.
///
/// Replaces a picker: at the two or three mints a wallet actually holds, a
/// swipe is cheaper than a list, and the balance you are swiping to is the
/// answer to the question the list was being opened to ask. Accounts ride the
/// same gesture rather than a second control, because choosing one is the
/// same act as choosing a mint — it names the balance being spent.
class _MintPager extends StatelessWidget {
  final List<ConduitClient> clients;
  // Keyed by [_clientKey], one entry per client in [clients].
  final Map<String, _AccountSession> sessions;
  // Keyed by the federation id's hex form, shared by that mint's pages.
  final Map<String, _MintSession> mints;
  final PageController controller;
  final BalanceDisplay display;
  final VoidCallback onBalanceTap;
  final VoidCallback onAccountTap;
  final void Function(int) onPageChanged;

  const _MintPager({
    required this.clients,
    required this.sessions,
    required this.mints,
    required this.controller,
    required this.display,
    required this.onBalanceTap,
    required this.onAccountTap,
    required this.onPageChanged,
  });

  Widget _page(ConduitClient client) => _MintPage(
    client: client,
    session: sessions[_clientKey(client)]!,
    mint: mints[client.federationIdHex()]!,
    display: display,
    onBalanceTap: onBalanceTap,
    onAccountTap: onAccountTap,
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Where the pager's height comes from. A viewport has no intrinsic
        // size, so a PageView is only ever as tall as its constraints make
        // it — and inside a column there are none to inherit. This lays a
        // page out to answer the question and never paints it, which beats
        // picking a number that has to be re-picked whenever the block
        // changes. Any page will do: the hero reserves its figure's full-size
        // line, so a page's height doesn't depend on its balance.
        TickerMode(
          enabled: false,
          child: IgnorePointer(
            child: Opacity(opacity: 0, child: _page(clients.first)),
          ),
        ),
        Positioned.fill(
          child: PageView.builder(
            controller: controller,
            itemCount: clients.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) => _page(clients[index]),
          ),
        ),
      ],
    );
  }
}

/// Where the pager is and how many pages there are to swipe through.
///
/// Watches the controller directly, so the pill slides with the finger rather
/// than snapping when a page settles — and so a swipe rebuilds the dots
/// instead of the screen.
class _PageDots extends StatelessWidget {
  final int count;
  final PageController controller;

  const _PageDots({required this.count, required this.controller});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          // No position to read until the pager has laid out, where it sits
          // on its initial page.
          final page =
              (controller.hasClients ? controller.page : null) ??
              controller.initialPage.toDouble();

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < count; i++)
                _dot(scheme, (1 - (page - i).abs()).clamp(0.0, 1.0)),
            ],
          );
        },
      ),
    );
  }

  /// One dot, [t] of the way from dormant to current: it widens into a pill
  /// as it takes over, so the page reads at a glance without relying on the
  /// colour alone.
  Widget _dot(ColorScheme scheme, double t) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 3),
    width: 6 + 12 * t,
    height: 6,
    decoration: BoxDecoration(
      color:
          Color.lerp(
            scheme.onSurfaceVariant.withValues(alpha: 0.3),
            scheme.primary,
            t,
          )!,
      borderRadius: BorderRadius.circular(3),
    ),
  );
}
