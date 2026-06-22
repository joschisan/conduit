import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/widgets/drawer_shell_widget.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/detail_row_widget.dart';
import 'package:conduit/utils/drawer_utils.dart';
import 'package:conduit/utils/currency_utils.dart';

class WalletV2WalletDetailsDrawer extends StatelessWidget {
  final ConduitClient client;
  final FederationStats stats;

  const WalletV2WalletDetailsDrawer({
    super.key,
    required this.client,
    required this.stats,
  });

  static Future<void> show(
    BuildContext context, {
    required ConduitClient client,
    required FederationStats stats,
  }) {
    return DrawerUtils.show(
      context: context,
      child: WalletV2WalletDetailsDrawer(client: client, stats: stats),
    );
  }

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
    final fiat = cachedFiatAmount(client, stats.totalValueSat);

    return DrawerShell(
      icon: PhosphorIconsRegular.info,
      title: 'Onchain Wallet Info',
      children: [
        BorderedList.column(
          children: [
            DetailRow(
              icon: PhosphorIconsRegular.currencyBtc,
              label: 'Bitcoin in Custody',
              value: _btc(stats.totalValueSat),
            ),
            if (fiat != null)
              DetailRow(
                icon: PhosphorIconsRegular.currencyDollar,
                label: '${fiat.currency} in Custody',
                value: fiat.amount,
              ),
            DetailRow(
              icon: PhosphorIconsRegular.cube,
              label: 'Block Count',
              value: _count(stats.blockCount),
            ),
            if (feerate != null)
              DetailRow(
                icon: PhosphorIconsRegular.speedometer,
                label: 'Feerate',
                value: _feerate(feerate),
              ),
          ],
        ),
      ],
    );
  }
}
