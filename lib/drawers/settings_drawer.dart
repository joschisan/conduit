import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/currency.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/widgets/drawer_shell_widget.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/settings_card_widget.dart';
import 'package:conduit/utils/drawer_utils.dart';

/// Bottom-sheet settings: app-wide rows (recovery phrase, currency) above the
/// current federation's rows (connectivity, remove). Each row pops the drawer
/// and hands off to a caller callback (the federation screen), whose stable
/// context owns the navigation.
class SettingsDrawer extends StatefulWidget {
  final ConduitClient client;
  final ConduitClientFactory clientFactory;
  final VoidCallback onSelectRecovery;
  final VoidCallback onSelectCurrency;
  final VoidCallback onSelectConnection;
  final VoidCallback onSelectRemove;

  const SettingsDrawer({
    super.key,
    required this.client,
    required this.clientFactory,
    required this.onSelectRecovery,
    required this.onSelectCurrency,
    required this.onSelectConnection,
    required this.onSelectRemove,
  });

  static Future<void> show(
    BuildContext context, {
    required ConduitClient client,
    required ConduitClientFactory clientFactory,
    required VoidCallback onSelectRecovery,
    required VoidCallback onSelectCurrency,
    required VoidCallback onSelectConnection,
    required VoidCallback onSelectRemove,
  }) {
    return DrawerUtils.show(
      context: context,
      child: SettingsDrawer(
        client: client,
        clientFactory: clientFactory,
        onSelectRecovery: onSelectRecovery,
        onSelectCurrency: onSelectCurrency,
        onSelectConnection: onSelectConnection,
        onSelectRemove: onSelectRemove,
      ),
    );
  }

  @override
  State<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends State<SettingsDrawer> {
  late final Stream<List<(String, bool)>> _connectionStream;
  String? _currencyName;
  String _federationName = 'Mint';

  @override
  void initState() {
    super.initState();
    _connectionStream = widget.client.subscribeConnectionStatus();
    _loadCurrency();
    widget.client.federationName().then((name) {
      if (mounted && name != null) setState(() => _federationName = name);
    });
  }

  Future<void> _loadCurrency() async {
    final code = await widget.clientFactory.getCurrency();

    if (!mounted) return;

    setState(() => _currencyName = findFiatCurrency(code: code)?.name);
  }

  /// Pops the drawer, then runs the caller's action against its own context.
  void _select(VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    return DrawerShell(
      children: [
        BorderedList.column(
          children: [
            _buildSeedPhraseCard(),
            _buildCurrencyCard(),
            _buildConnectionCard(),
            _buildRemoveCard(),
          ],
        ),
      ],
    );
  }

  Widget _buildSeedPhraseCard() {
    return SettingsCard(
      icon: PhosphorIconsRegular.key,
      title: 'Recovery Phrase',
      subtitle: 'Backup your wallet',
      onTap: () => _select(widget.onSelectRecovery),
    );
  }

  Widget _buildCurrencyCard() {
    return SettingsCard(
      icon: PhosphorIconsRegular.currencyDollar,
      title: 'Select Currency',
      subtitle: _currencyName,
      onTap: () => _select(widget.onSelectCurrency),
    );
  }

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

  Widget _buildRemoveCard() {
    return SettingsCard(
      icon: PhosphorIconsRegular.signOut,
      title: 'Remove $_federationName',
      subtitle: 'Delete eCash and history',
      onTap: () => _select(widget.onSelectRemove),
    );
  }
}
