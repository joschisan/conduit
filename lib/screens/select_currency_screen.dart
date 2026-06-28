import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/bridge_generated.dart/currency.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/widgets/grouped_list_widget.dart';
import 'package:conduit/widgets/icon_chip_widget.dart';
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
              leading: const IconChip(
                icon: PhosphorIconsRegular.currencyDollar,
              ),
              // Stack name/code in the title (not subtitle) to keep the tile's
              // single-line height instead of growing to two-line.
              title: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(currency.name, style: mediumStyle),
                  Text(
                    currency.code,
                    style: smallStyle.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              onTap: () async {
                await widget.clientFactory.setCurrency(
                  currencyCode: currency.code,
                );

                if (context.mounted) Navigator.of(context).pop();
              },
            ),
      ),
    );
  }
}
