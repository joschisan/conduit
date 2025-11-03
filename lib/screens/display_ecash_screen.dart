import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/widgets/amount_display.dart';
import 'package:conduit/widgets/qr_code_widget.dart';
import 'package:conduit/widgets/copy_button.dart';

Stream<String> _createFrameStream(OobNotesEncoder encoder) async* {
  while (true) {
    yield await encoder.nextFragment();
    await Future.delayed(const Duration(milliseconds: 300));
  }
}

class DisplayEcashScreen extends StatelessWidget {
  final OobNotesEncoder encoder;
  final String ecashNotes;
  final int amount;

  const DisplayEcashScreen({
    super.key,
    required this.encoder,
    required this.ecashNotes,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('eCash')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AmountDisplay(amount),
              const SizedBox(height: 24),
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
              CopyButton(
                data: ecashNotes,
                message: 'eCash copied to clipboard',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
