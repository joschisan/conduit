import 'package:flutter/material.dart';
import 'package:currency_picker/currency_picker.dart';
import '../bridge_generated.dart/lib.dart';

class CurrencySelectionScreen extends StatelessWidget {
  final ConduitClientFactory clientFactory;

  const CurrencySelectionScreen({super.key, required this.clientFactory});

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
                leading: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    currency.code,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
                trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                onTap: () async {
                  await clientFactory.setCurrency(currencyCode: currency.code);

                  if (!context.mounted) return;

                  Navigator.pop(context);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
