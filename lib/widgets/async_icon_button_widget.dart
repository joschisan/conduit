import 'package:flutter/material.dart';
import 'package:conduit/utils/async_button_mixin.dart';

class AsyncIconButton extends StatefulWidget {
  final IconData icon;
  final Future<void> Function() onPressed;

  const AsyncIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<AsyncIconButton> createState() => _AsyncIconButtonState();
}

class _AsyncIconButtonState extends State<AsyncIconButton>
    with AsyncButtonMixin {
  @override
  Future<void> Function() get onPressed => widget.onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: switch (buttonState) {
        AsyncButtonState.idle => handlePress,
        AsyncButtonState.loading => null,
      },
      icon: switch (buttonState) {
        AsyncButtonState.loading => SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        AsyncButtonState.idle => Icon(widget.icon),
      },
    );
  }
}
