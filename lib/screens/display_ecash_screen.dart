import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/fountain.dart';
import 'package:conduit/widgets/amount_display.dart';
import 'package:conduit/widgets/qr_code_widget.dart';
import 'package:conduit/drawers/cancel_ecash_drawer.dart';

Stream<String> _createFrameStream(OobNotesEncoder encoder) async* {
  while (true) {
    yield await encoder.nextFragment();
    await Future.delayed(const Duration(milliseconds: 300));
  }
}

class DisplayEcashScreen extends StatelessWidget {
  final ConduitClient client;
  final OobNotesWrapper notes;
  final OobNotesEncoder encoder;

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
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _showCancelDrawer(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: Icon(
                    Icons.toll,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              StreamBuilder<String>(
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
              Expanded(child: Center(child: AmountDisplay(notes.amountSats()))),
            ],
          ),
        ),
      ),
    );
  }
}
