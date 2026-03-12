import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/widgets/drawer_shell_widget.dart';
import 'package:conduit/widgets/async_button_widget.dart';
import 'package:conduit/utils/drawer_utils.dart';
import 'package:conduit/utils/currency_utils.dart';

class ConfirmCurrencyDrawer extends StatefulWidget {
  final FiatCurrency currency;
  final ConduitClientFactory clientFactory;

  const ConfirmCurrencyDrawer({
    super.key,
    required this.currency,
    required this.clientFactory,
  });

  static Future<void> show(
    BuildContext context, {
    required FiatCurrency currency,
    required ConduitClientFactory clientFactory,
  }) {
    return DrawerUtils.show(
      context: context,
      child: ConfirmCurrencyDrawer(
        currency: currency,
        clientFactory: clientFactory,
      ),
    );
  }

  @override
  State<ConfirmCurrencyDrawer> createState() => _ConfirmCurrencyDrawerState();
}

class _ConfirmCurrencyDrawerState extends State<ConfirmCurrencyDrawer> {
  Future<void> _handleConfirm() async {
    await widget.clientFactory.setCurrency(currencyCode: widget.currency.code);

    if (!mounted) return;

    Navigator.of(context).pop();

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DrawerShell(
      icon: Icons.currency_exchange,
      title: 'Select ${widget.currency.name}?',
      children: [AsyncButton(text: 'Confirm', onPressed: _handleConfirm)],
    );
  }
}
