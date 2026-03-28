import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/drawers/confirm_currency_drawer.dart';
import 'package:conduit/bridge_generated.dart/currency.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/widgets/grouped_list_widget.dart';
import 'package:conduit/widgets/search_field_widget.dart';

class SelectCurrencyScreen extends StatefulWidget {
  final ConduitClientFactory clientFactory;

  const SelectCurrencyScreen({super.key, required this.clientFactory});

  @override
  State<SelectCurrencyScreen> createState() => _SelectCurrencyScreenState();
}

class _SelectCurrencyScreenState extends State<SelectCurrencyScreen> {
  String _query = '';

  List<FiatCurrency> get _filtered =>
      listFiatCurrencies()
          .where(
            (c) =>
                c.code.toLowerCase().contains(_query.toLowerCase()) ||
                c.name.toLowerCase().contains(_query.toLowerCase()),
          )
          .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Currency')),
      body: GroupedList<FiatCurrency>(
        header: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SearchField(
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        items: _filtered,
        groupKey: (currency) => currency.code[0],
        itemBuilder:
            (context, currency) => ListTile(
              contentPadding: listTilePadding,
              leading: SizedBox(
                width: 72,
                child: Text(
                  currency.code,
                  textAlign: TextAlign.center,
                  style: largeStyle.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              title: Text(currency.name, style: mediumStyle),
              onTap: () {
                ConfirmCurrencyDrawer.show(
                  context,
                  currency: currency,
                  clientFactory: widget.clientFactory,
                );
              },
            ),
      ),
    );
  }
}
