import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart' hide State;
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
    FClient client,
  )
  onAmountSubmitted;
  final FClient client;
  final bool showLnurlButton;

  const AmountScreen({
    super.key,
    required this.onAmountSubmitted,
    required this.client,
    this.showLnurlButton = false,
  });

  @override
  State<AmountScreen> createState() => _AmountScreenState();
}

class _AmountScreenState extends State<AmountScreen> {
  String _currentAmount = '';

  void _onKeyboardTap(String value) {
    if (_currentAmount.length >= 8) return;

    setState(() {
      _currentAmount += value;
    });
  }

  void _onBackspace() {
    if (_currentAmount.isNotEmpty) {
      setState(() {
        _currentAmount = _currentAmount.substring(0, _currentAmount.length - 1);
      });
    }
  }

  void _onClear() {
    setState(() {
      _currentAmount = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions:
            widget.showLnurlButton
                ? [AsyncTextButton(text: 'LNURL', onPressed: _handleLnurlTap)]
                : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Amount display - fills remaining space above continue button
            Expanded(
              child: Center(
                child: AmountDisplay(
                  _currentAmount.isEmpty ? 0 : int.parse(_currentAmount),
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

  TaskEither<String, void> _handleSubmit() {
    if (_currentAmount.isEmpty) {
      return TaskEither.left('Please enter an amount');
    }

    final amountSats = int.parse(_currentAmount);

    return widget.onAmountSubmitted(amountSats, context, widget.client);
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
