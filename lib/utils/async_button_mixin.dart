import 'package:flutter/material.dart';
import '../utils/notification_utils.dart';

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
