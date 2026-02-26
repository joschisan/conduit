import 'package:flutter/material.dart';
import 'package:currency_picker/currency_picker.dart';
import '../bridge_generated.dart/factory.dart';
import '../drawers/confirm_currency_drawer.dart';

class SelectCurrencyScreen extends StatelessWidget {
  final ConduitClientFactory clientFactory;

  const SelectCurrencyScreen({super.key, required this.clientFactory});

  @override
  Widget build(BuildContext context) {
    final currencies =
        CurrencyService()
            .getAll()
            .where(
              (currency) => [
                'ARS',
                'AUD',
                'BRL',
                'CAD',
                'CHF',
                'CLP',
                'CZK',
                'DKK',
                'EUR',
                'GBP',
                'HKD',
                'HUF',
                'IDR',
                'ILS',
                'INR',
                'JPY',
                'KRW',
                'MXN',
                'MYR',
                'NOK',
                'NZD',
                'PHP',
                'PLN',
                'SEK',
                'SGD',
                'THB',
                'TRY',
                'USD',
                'ZAR',
              ].contains(currency.code),
            )
            .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Select Currency')),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: currencies.length,
          itemBuilder: (context, index) {
            final currency = currencies[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: SizedBox(
                  width: 56,
                  child: Text(
                    currency.code,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ),
                title: Text(
                  currency.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  ConfirmCurrencyDrawer.show(
                    context,
                    currency: currency,
                    clientFactory: clientFactory,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
