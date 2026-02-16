import 'package:flutter/material.dart';
import 'package:conduit/utils/async_button_mixin.dart';

class AsyncButton extends StatefulWidget {
  final String text;
  final Future<void> Function() onPressed;

  const AsyncButton({super.key, required this.text, required this.onPressed});

  @override
  State<AsyncButton> createState() => _AsyncButtonState();
}

class _AsyncButtonState extends State<AsyncButton> with AsyncButtonMixin {
  @override
  Future<void> Function() get onPressed => widget.onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: switch (buttonState) {
          AsyncButtonState.idle => handlePress,
          AsyncButtonState.loading => null,
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: switch (buttonState) {
          AsyncButtonState.loading => const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          AsyncButtonState.idle => Text(
            widget.text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        },
      ),
    );
  }
}
