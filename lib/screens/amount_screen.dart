import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart' hide State;
import 'package:intl/intl.dart';
import 'package:currency_picker/currency_picker.dart';
import 'package:conduit/widgets/async_action_button.dart';
import 'package:conduit/widgets/async_text_button.dart';
import 'package:conduit/widgets/amount_display.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/screens/display_lnurl_screen.dart';
import 'package:conduit/utils/fp_utils.dart';

class AmountScreen extends StatefulWidget {
  final TaskEither<String, void> Function(
    int amountSats,
    BuildContext context,
    ConduitClient client,
  )
  onAmountSubmitted;
  final ConduitClient client;
  final bool showLnurlButton;
  final BitcoinAddressWrapper? bitcoinAddress;

  const AmountScreen({
    super.key,
    required this.onAmountSubmitted,
    required this.client,
    this.showLnurlButton = false,
    this.bitcoinAddress,
  });

  @override
  State<AmountScreen> createState() => _AmountScreenState();
}

class _AmountScreenState extends State<AmountScreen> {
  String _currentAmount = '';
  Future<int>? _feeFuture;
  bool _enterFiat = false;

  Currency get _currency {
    final currencyCode = widget.client.currencyCode();

    return CurrencyService().getAll().firstWhere((c) => c.code == currencyCode);
  }

  void _onKeyboardTap(String value) {
    if (_currentAmount.length >= 8) return;

    setState(() {
      _currentAmount += value;
    });

    // Prefetch exchange rates while user is typing
    widget.client.prefetchExchangeRates();

    _updateFees();
  }

  void _onBackspace() {
    if (_currentAmount.isNotEmpty) {
      setState(() {
        _currentAmount = _currentAmount.substring(0, _currentAmount.length - 1);
      });
      _updateFees();
    }
  }

  void _onClear() {
    setState(() {
      _currentAmount = '';
      _feeFuture = null;
    });
  }

  void _updateFees() {
    if (widget.bitcoinAddress == null) return;

    if (_currentAmount.isEmpty) {
      setState(() {
        _feeFuture = null;
      });
    } else {
      setState(() {
        _feeFuture = widget.client.onchainCalculateFees(
          address: widget.bitcoinAddress!,
          amountSats: int.parse(_currentAmount),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (widget.showLnurlButton)
            AsyncTextButton(text: 'LNURL', onPressed: _handleLnurlTap)
          else if (widget.bitcoinAddress != null && _currentAmount.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: FutureBuilder<int>(
                  future: _feeFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    } else if (snapshot.hasError) {
                      return const Text(
                        'Failed to calculate fee',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      );
                    } else if (snapshot.hasData) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          'Fee: ${snapshot.data} sats',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Amount display - fills remaining space above continue button
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _enterFiat = !_enterFiat;
                    });
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _formatAmount(),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _enterFiat ? _currency.name : 'Bitcoin',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Continue button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: AsyncActionButton(
                text: 'Continue',
                onPressed: _handleSubmit,
              ),
            ),

            // Custom number pad - explicit buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio:
                    2.0, // Makes buttons less tall (wider than tall)
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
                  _buildActionButton(Icons.backspace_outlined, _onBackspace),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberButton(String number) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _onKeyboardTap(number),
        child: Center(
          child: Text(
            number,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Center(
          child: Icon(
            icon,
            size: 28,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  String _formatAmount() {
    final amount = _currentAmount.isEmpty ? 0 : int.parse(_currentAmount);

    if (_enterFiat) {
      return '${NumberFormat('#,##0.00').format(amount / 100)} ${_currency.symbol}';
    } else {
      return '$amount sats';
    }
  }

  TaskEither<String, void> _handleSubmit() {
    if (_currentAmount.isEmpty) {
      return TaskEither.left('Please enter an amount');
    }

    if (!_enterFiat) {
      final amountSats = int.parse(_currentAmount);

      return widget.onAmountSubmitted(amountSats, context, widget.client);
    } else {
      return safeTask(() async {
        final amountFiatCents = int.parse(_currentAmount);

        final amountSats = await widget.client.fiatToSats(
          amountFiatCents: amountFiatCents,
        );

        if (!context.mounted) return;

        await widget
            .onAmountSubmitted(amountSats, context, widget.client)
            .run();
      });
    }
  }

  TaskEither<String, void> _handleLnurlTap() {
    return safeTask(() async {
      final lnurl = await widget.client.lnurl();

      if (!context.mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => DisplayLnurlScreen(lnurl: lnurl)),
      );
    });
  }
}
