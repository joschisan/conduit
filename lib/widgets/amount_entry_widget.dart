import 'dart:math';

import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
import 'package:intl/intl.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/currency.dart';
import 'package:conduit/widgets/amount_display_widget.dart';
import 'package:conduit/widgets/async_button_widget.dart';

class AmountEntryWidget extends StatefulWidget {
  final ConduitClient client;
  final Future<void> Function(int amountSats) onConfirm;
  final void Function(int currentAmount)? onAmountChanged;

  const AmountEntryWidget({
    super.key,
    required this.client,
    required this.onConfirm,
    this.onAmountChanged,
  });

  @override
  State<AmountEntryWidget> createState() => _AmountEntryWidgetState();
}

class _AmountEntryWidgetState extends State<AmountEntryWidget> {
  int _currentAmount = 0;
  bool _enterFiat = false;

  FiatCurrency get _currency {
    return findFiatCurrency(code: widget.client.currencyCode())!;
  }

  void _onKeyboardTap(String value) {
    if (_currentAmount.toString().length >= 8) return;

    setState(() {
      _currentAmount = _currentAmount * 10 + int.parse(value);
    });

    // Notify parent about amount change (always in sat)
    _notifyParentAmountChanged();
  }

  void _onBackspace() {
    if (_currentAmount > 0) {
      setState(() {
        _currentAmount = _currentAmount ~/ 10;
      });

      // Notify parent about amount change (always in sat)
      _notifyParentAmountChanged();
    }
  }

  void _onClear() {
    setState(() {
      _currentAmount = 0;
    });

    // Notify parent about amount change
    widget.onAmountChanged?.call(0);
  }

  Future<void> _notifyParentAmountChanged() async {
    if (widget.onAmountChanged == null) return;

    if (_enterFiat) {
      final amountSats = await widget.client.fiatToSats(
        amountFiat: _fiatAmount,
      );
      widget.onAmountChanged?.call(amountSats);
    } else {
      // Already in sat
      widget.onAmountChanged?.call(_currentAmount);
    }
  }

  double get _fiatAmount => _currentAmount / pow(10, _currency.decimalDigits);

  String _formatFiatAmount() {
    final format =
        _currency.decimalDigits > 0
            ? '#,##0.${'0' * _currency.decimalDigits}'
            : '#,##0';
    return '${_currency.symbol} ${NumberFormat(format).format(_fiatAmount)}';
  }

  Future<void> _handleConfirm() async {
    if (_currentAmount == 0) {
      throw 'Please enter an amount';
    }

    final amountSats =
        _enterFiat
            ? await widget.client.fiatToSats(amountFiat: _fiatAmount)
            : _currentAmount;

    await widget.onConfirm(amountSats);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Amount display - fills remaining space above confirm button
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _enterFiat = !_enterFiat;
              });

              // Prefetch exchange rates when switching to fiat mode
              if (_enterFiat) {
                widget.client.prefetchExchangeRates();
              }
            },
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_enterFiat)
                    Text.rich(
                      textAlign: TextAlign.center,
                      TextSpan(text: _formatFiatAmount(), style: heroStyle),
                    )
                  else
                    AmountDisplay(_currentAmount),
                  const SizedBox(height: 8),
                  Text(
                    _enterFiat ? _currency.name : 'Bitcoin',
                    style: mediumStyle.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Confirm button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: AsyncButton(text: 'Confirm', onPressed: _handleConfirm),
        ),

        const SizedBox(height: 16),

        // Custom number pad
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.0,
          children: [
            _buildNumberButton('1'),
            _buildNumberButton('2'),
            _buildNumberButton('3'),
            _buildNumberButton('4'),
            _buildNumberButton('5'),
            _buildNumberButton('6'),
            _buildNumberButton('7'),
            _buildNumberButton('8'),
            _buildNumberButton('9'),
            _buildActionButton(Icons.clear, _onClear),
            _buildNumberButton('0'),
            _buildActionButton(Icons.arrow_back, _onBackspace),
          ],
        ),
      ],
    );
  }

  Widget _buildNumberButton(String number) {
    return Material(
      color: Colors.transparent,
      borderRadius: borderRadiusLarge,
      child: InkWell(
        borderRadius: borderRadiusLarge,
        onTap: () => _onKeyboardTap(number),
        child: Center(child: Text(number, style: largeStyle)),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      borderRadius: borderRadiusLarge,
      child: InkWell(
        borderRadius: borderRadiusLarge,
        onTap: onTap,
        child: Center(child: Icon(icon, size: smallIconSize)),
      ),
    );
  }
}
