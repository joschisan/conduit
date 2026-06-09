import 'dart:async';

import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/drawers/wallet_v2_wallet_details_drawer.dart';
import 'package:conduit/widgets/async_icon_button_widget.dart';
import 'package:conduit/widgets/qr_code_widget.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/shareable_row_widget.dart';

class WalletV2ReceiveScreen extends StatelessWidget {
  final String address;
  final ConduitClient client;

  const WalletV2ReceiveScreen({
    super.key,
    required this.address,
    required this.client,
  });

  Future<void> _showDetails(BuildContext context) async {
    final stats = await client.federationStats();

    if (stats == null || !context.mounted) return;

    // Don't await the drawer's dismissal here, otherwise the icon's spinner
    // keeps running for as long as the drawer stays open.
    unawaited(WalletV2WalletDetailsDrawer.show(context, stats: stats));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Onchain Address'),
        actions: [
          AsyncIconButton(
            icon: PhosphorIconsRegular.info,
            onPressed: () => _showDetails(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 16),
              QrCodeWidget(data: address),
              const SizedBox(height: 16),
              BorderedList.column(
                children: [
                  ShareableRow(data: address, label: 'Bitcoin Address'),
                ],
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      'Confirmed onchain payments will take about two hours to appear.',
                      style: smallStyle.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
