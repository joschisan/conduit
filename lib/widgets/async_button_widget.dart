import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/utils/async_button_mixin.dart';

class AsyncButton extends StatefulWidget {
  final String text;
  final Future<void> Function() onPressed;
  final bool enabled;
  // Background colour of the button; defaults to the primary colour. The label
  // always uses the on-primary foreground.
  final Color? color;

  const AsyncButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.enabled = true,
    this.color,
  });

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
          AsyncButtonState.idle => widget.enabled ? handlePress : null,
          AsyncButtonState.loading => null,
        },
        style: ElevatedButton.styleFrom(
          backgroundColor:
              widget.color ?? Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: const RoundedRectangleBorder(borderRadius: cornerRadius),
        ),
        child: switch (buttonState) {
          AsyncButtonState.loading => smallSpinner,
          AsyncButtonState.idle => Text(widget.text, style: mediumStyle),
        },
      ),
    );
  }
}
