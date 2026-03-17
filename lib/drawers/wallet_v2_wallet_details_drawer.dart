import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/widgets/drawer_shell_widget.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/utils/drawer_utils.dart';

class WalletV2WalletDetailsDrawer extends StatelessWidget {
  final FederationStats stats;

  const WalletV2WalletDetailsDrawer({super.key, required this.stats});

  static Future<void> show(
    BuildContext context, {
    required FederationStats stats,
  }) {
    return DrawerUtils.show(
      context: context,
      child: WalletV2WalletDetailsDrawer(stats: stats),
    );
  }

  // Stack the value over the label inside the title slot (rather than using
  // ListTile.subtitle) so the tile keeps the single-line height of the other
  // bordered lists while still showing a header and subheader.
  Widget _stat(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) => ListTile(
    contentPadding: listTilePadding,
    leading: Icon(
      icon,
      size: mediumIconSize,
      color: Theme.of(context).colorScheme.primary,
    ),
    title: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: mediumStyle),
        Text(
          label,
          style: smallStyle.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );

  String _btc(int sats) => '${(sats / 100000000).toStringAsFixed(8)} BTC';

  String _count(int n) => NumberFormat('#,###').format(n);

  // The consensus feerate is reported in sats per 1000 vbytes (kvB),
  // so divide by 1000 to display it as sat/vB with a decimal point.
  String _feerate(int satPerKvb) {
    final value = (satPerKvb / 1000).toStringAsFixed(3);

    return '${value.replaceFirst(RegExp(r'\.?0+$'), '')} sat/vB';
  }

  @override
  Widget build(BuildContext context) {
    final feerate = stats.feerate;

    return DrawerShell(
      icon: PhosphorIconsRegular.info,
      title: 'Onchain Wallet Info',
      children: [
        BorderedList.column(
          children: [
            _stat(
              context,
              PhosphorIconsRegular.currencyBtc,
              'Value in Custody',
              _btc(stats.totalValueSat),
            ),
            _stat(
              context,
              PhosphorIconsRegular.cube,
              'Block Count',
              _count(stats.blockCount),
            ),
            if (feerate != null)
              _stat(
                context,
                PhosphorIconsRegular.speedometer,
                'Feerate',
                _feerate(feerate),
              ),
          ],
        ),
      ],
    );
  }
}
