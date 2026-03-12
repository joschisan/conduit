import 'package:flutter/material.dart';
import 'package:conduit/utils/notification_utils.dart';
import 'package:flutter/services.dart';

Widget buildSmallSpinner(BuildContext context) => SizedBox(
  width: 20,
  height: 20,
  child: CircularProgressIndicator(
    strokeWidth: 2,
    valueColor: AlwaysStoppedAnimation<Color>(
      Theme.of(context).colorScheme.primary,
    ),
  ),
);

enum AsyncButtonState { idle, loading }

mixin AsyncButtonMixin<T extends StatefulWidget> on State<T> {
  AsyncButtonState _state = AsyncButtonState.idle;

  AsyncButtonState get buttonState => _state;

  Future<void> Function() get onPressed;

  void _updateState(AsyncButtonState newState) {
    if (!mounted) return;

    setState(() => _state = newState);
  }

  Future<void> handlePress() async {
    HapticFeedback.lightImpact();
    _updateState(AsyncButtonState.loading);

    try {
      await onPressed();
      _updateState(AsyncButtonState.idle);
    } catch (error) {
      _updateState(AsyncButtonState.idle);

      if (mounted) {
        NotificationUtils.showError(context, error.toString());
      }
    }
  }
}
