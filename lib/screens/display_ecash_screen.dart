import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/fountain.dart';
import 'package:conduit/widgets/qr_code_widget.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/shareable_row_widget.dart';
import 'package:conduit/widgets/detail_row_widget.dart';
import 'package:conduit/drawers/cancel_ecash_drawer.dart';

Stream<String> _createFrameStream(ECashEncoder encoder) async* {
  while (true) {
    yield await encoder.nextFragment();
    await Future.delayed(const Duration(milliseconds: 300));
  }
}

class DisplayEcashScreen extends StatelessWidget {
  final ConduitClient client;
  final ECashWrapper notes;
  final ECashEncoder encoder;
  final ({String name, String amount})? fiatAmount;

  const DisplayEcashScreen({
    super.key,
    required this.client,
    required this.notes,
    required this.encoder,
    this.fiatAmount,
  });

  void _showCancelDrawer(BuildContext context) {
    CancelEcashDrawer.show(context, client: client, notes: notes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send eCash'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.xCircle, size: smallIconSize),
            onPressed: () => _showCancelDrawer(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              StreamBuilder<String>(
                stream: _createFrameStream(encoder),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return QrCodeWidget(data: snapshot.data!);
                },
              ),
              const SizedBox(height: 16),
              BorderedList.column(
                children: [
                  ShareableRow(data: notes.toString(), label: 'eCash'),
                  DetailRow(
                    icon: PhosphorIconsRegular.currencyBtc,
                    label: 'Amount in Bitcoin',
                    value:
                        '${NumberFormat('#,###').format(notes.amountSats())} sat',
                  ),
                  if (fiatAmount != null)
                    DetailRow(
                      icon: PhosphorIconsRegular.currencyDollar,
                      label: 'Amount in ${fiatAmount!.name}',
                      value: fiatAmount!.amount,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
