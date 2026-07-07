import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/widgets/drawer_shell_widget.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/settings_card_widget.dart';
import 'package:conduit/utils/drawer_utils.dart';

/// Bottom-sheet federation switcher. Lists every joined federation; tapping one
/// switches to it (re-selecting the current federation simply reloads it). The
/// outgoing federation screen tears its client down in `dispose`. Joining a new
/// federation is done through the regular scanner, and leaving one from its
/// connection screen.
class SelectFederationDrawer extends StatefulWidget {
  final ConduitClientFactory clientFactory;
  final void Function(FederationInfo) onSelect;

  const SelectFederationDrawer({
    super.key,
    required this.clientFactory,
    required this.onSelect,
  });

  static Future<void> show(
    BuildContext context, {
    required ConduitClientFactory clientFactory,
    required void Function(FederationInfo) onSelect,
  }) {
    return DrawerUtils.show(
      context: context,
      child: SelectFederationDrawer(
        clientFactory: clientFactory,
        onSelect: onSelect,
      ),
    );
  }

  @override
  State<SelectFederationDrawer> createState() => _SelectFederationDrawerState();
}

class _SelectFederationDrawerState extends State<SelectFederationDrawer> {
  List<FederationInfo> _federations = [];

  @override
  void initState() {
    super.initState();
    _loadFederations();
  }

  Future<void> _loadFederations() async {
    final federations = await widget.clientFactory.listFederations();

    if (!mounted) return;

    setState(() {
      _federations = federations;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DrawerShell(
      children: [
        BorderedList.column(
          children: [for (final f in _federations) _buildFederationRow(f)],
        ),
      ],
    );
  }

  Widget _buildFederationRow(FederationInfo federation) {
    final guardians = federation.guardians;

    return SettingsCard(
      icon: PhosphorIconsRegular.wallet,
      title: federation.name,
      subtitle: '$guardians ${guardians == 1 ? 'Guardian' : 'Guardians'}',
      onTap: () {
        Navigator.of(context).pop();
        widget.onSelect(federation);
      },
    );
  }
}
