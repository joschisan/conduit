import 'package:flutter/material.dart';
import 'package:conduit/utils/async_button_mixin.dart';
import 'package:conduit/utils/styles.dart';

/// The app bar's Max action: sends everything on tap, straight to the screen
/// that displays the result, never through the amount entry. The button is
/// always offered, shows a spinner while the send runs, and surfaces "can't"
/// (an empty account, a mint that cannot offer it) as a notification rather
/// than by not existing.
///
/// Carries the same duties the big confirm button carries for typed amounts:
/// the mixin adds the haptic, the busy state the spinner renders, and errors
/// surfaced as notifications.
class MaxAction extends StatefulWidget {
  final Future<void> Function() onPressed;

  const MaxAction({super.key, required this.onPressed});

  @override
  State<MaxAction> createState() => _MaxActionState();
}

class _MaxActionState extends State<MaxAction> with AsyncButtonMixin {
  @override
  Future<void> Function() get onPressed => widget.onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: buttonState == AsyncButtonState.idle ? handlePress : null,
      child: switch (buttonState) {
        AsyncButtonState.loading => smallSpinner,
        AsyncButtonState.idle => Text(
          'Max',
          style: mediumStyle.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      },
    );
  }
}
