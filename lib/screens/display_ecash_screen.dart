import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/fountain.dart';
import 'package:conduit/widgets/amount_display_widget.dart';
import 'package:conduit/widgets/qr_code_widget.dart';
import 'package:conduit/widgets/qr_display_layout_widget.dart';
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

  const DisplayEcashScreen({
    super.key,
    required this.client,
    required this.notes,
    required this.encoder,
  });

  void _showCancelDrawer(BuildContext context) {
    CancelEcashDrawer.show(context, client: client, notes: notes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('eCash'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cancel, size: smallIconSize),
            onPressed: () => _showCancelDrawer(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: QrDisplayLayout(
            header: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.toll,
                  size: heroIconSize,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 16),
                AmountDisplay(notes.amountSats()),
              ],
            ),
            qrCode: StreamBuilder<String>(
              stream: _createFrameStream(encoder),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return QrCodeWidget(
                  data: snapshot.data!,
                  copyData: notes.toString(),
                );
              },
            ),
            description:
                'Any member of this federation can claim these funds by scanning this ecash token. The token cannot be linked to you.',
          ),
        ),
      ),
    );
  }
}
