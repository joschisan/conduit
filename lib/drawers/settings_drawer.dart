import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/currency.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/utils/account_utils.dart';
import 'package:conduit/widgets/drawer_shell_widget.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/settings_card_widget.dart';
import 'package:conduit/utils/drawer_utils.dart';

/// Bottom-sheet settings: app-wide rows (recovery phrase, currency) above the
/// selected account's own (which account, connectivity, and removing the
/// mint). Each row pops the drawer and hands off to a caller callback (the
/// home screen), whose stable context owns the navigation — this drawer's
/// own context dies with the pop.
class SettingsDrawer extends StatefulWidget {
  final ConduitClient client;
  final ConduitClientFactory clientFactory;
  final VoidCallback onSelectRecovery;
  final VoidCallback onSelectCurrency;
  final VoidCallback onSelectAccount;
  final VoidCallback onSelectConnection;
  // Null with only one mint added: removing the last one would strand the
  // wallet on onboarding, so the row is left out entirely.
  final VoidCallback? onSelectRemove;

  const SettingsDrawer({
    super.key,
    required this.client,
    required this.clientFactory,
    required this.onSelectRecovery,
    required this.onSelectCurrency,
    required this.onSelectAccount,
    required this.onSelectConnection,
    required this.onSelectRemove,
  });

  static Future<void> show(
    BuildContext context, {
    required ConduitClient client,
    required ConduitClientFactory clientFactory,
    required VoidCallback onSelectRecovery,
    required VoidCallback onSelectCurrency,
    required VoidCallback onSelectAccount,
    required VoidCallback onSelectConnection,
    required VoidCallback? onSelectRemove,
  }) {
    return DrawerUtils.show(
      context: context,
      child: SettingsDrawer(
        client: client,
        clientFactory: clientFactory,
        onSelectRecovery: onSelectRecovery,
        onSelectCurrency: onSelectCurrency,
        onSelectAccount: onSelectAccount,
        onSelectConnection: onSelectConnection,
        onSelectRemove: onSelectRemove,
      ),
    );
  }

  @override
  State<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends State<SettingsDrawer> {
  // Cached so rebuilds don't re-subscribe.
  late final Stream<List<(String, bool)>> _connectionStream =
      widget.client.subscribeConnectionStatus();

  late final String? _currencyName =
      findFiatCurrency(code: widget.clientFactory.getCurrency())?.name;

  /// Pops the drawer, then runs the caller's action against its own context.
  void _select(VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final onSelectRemove = widget.onSelectRemove;

    return DrawerShell(
      children: [
        BorderedList.column(
          children: [
            SettingsCard(
              icon: PhosphorIconsRegular.key,
              title: 'Recovery Phrase',
              subtitle: 'Backup your wallet',
              onTap: () => _select(widget.onSelectRecovery),
            ),
            SettingsCard(
              icon: PhosphorIconsRegular.currencyDollar,
              title: 'Select Currency',
              subtitle: _currencyName,
              onTap: () => _select(widget.onSelectCurrency),
            ),
            SettingsCard(
              icon: PhosphorIconsRegular.wallet,
              title: 'Select Account',
              subtitle: widget.client.account().displayName,
              onTap: () => _select(widget.onSelectAccount),
            ),
            _buildConnectionCard(),
            // Destroys what the mint still holds, so it sits at the bottom
            // away from the rows that only navigate.
            if (onSelectRemove != null)
              SettingsCard(
                icon: PhosphorIconsRegular.signOut,
                title: 'Remove ${widget.client.federationName()}',
                subtitle: 'Delete eCash and history',
                onTap: () => _select(onSelectRemove),
              ),
          ],
        ),
      ],
    );
  }

  /// Carries the same amber/plain split as the home row, so opening settings
  /// on a degraded mint says so before the screen behind it is gone.
  Widget _buildConnectionCard() {
    return StreamBuilder<List<(String, bool)>>(
      stream: _connectionStream,
      builder: (context, snapshot) {
        String? subtitle;
        Color? iconColor;

        if (snapshot.hasData) {
          final statuses = snapshot.data!;
          final online = statuses.where((s) => s.$2).length;
          // Amber below fedimint's consensus threshold (n - ⌊(n-1)/3⌋).
          final threshold = statuses.length - ((statuses.length - 1) ~/ 3);
          final operational = online >= threshold;

          subtitle = operational ? 'Online' : 'Offline';
          if (!operational) iconColor = Colors.amber;
        }

        return SettingsCard(
          icon: PhosphorIconsRegular.broadcast,
          iconColor: iconColor,
          title: 'Connectivity',
          subtitle: subtitle,
          onTap: () => _select(widget.onSelectConnection),
        );
      },
    );
  }
}
