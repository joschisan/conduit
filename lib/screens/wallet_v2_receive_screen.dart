import 'package:flutter/material.dart';
import 'package:conduit/widgets/address_card_widget.dart';
import 'package:conduit/widgets/qr_code_widget.dart';

class WalletV2ReceiveScreen extends StatelessWidget {
  final String address;

  const WalletV2ReceiveScreen({super.key, required this.address});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('Onchain Address')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Center(
                        child: Icon(
                          Icons.currency_bitcoin,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    QrCodeWidget(data: address),
                    const SizedBox(height: 16),
                    AddressCard(address: address),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0),
                          child: Text(
                            'Confirmed onchain payments will take about an hour to appear.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
