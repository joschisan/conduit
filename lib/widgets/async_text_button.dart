import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart' hide State;
import '../utils/notification_utils.dart';

enum AsyncTextButtonState { idle, loading }

class AsyncTextButton extends StatefulWidget {
  final String text;
  final TaskEither<String, void> Function() onPressed;
  final VoidCallback? onSuccess;

  const AsyncTextButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.onSuccess,
  });

  @override
  State<AsyncTextButton> createState() => _AsyncTextButtonState();
}

class _AsyncTextButtonState extends State<AsyncTextButton> {
  AsyncTextButtonState _state = AsyncTextButtonState.idle;

  void _updateState(AsyncTextButtonState newState) {
    if (!mounted) return;

    setState(() => _state = newState);
  }

  void _showError(String message) {
    if (!mounted) return;

    NotificationUtils.showError(context, message);
  }

  Future<void> _handleTap() async {
    _updateState(AsyncTextButtonState.loading);

    final result = await widget.onPressed().run();

    result.fold(
      (error) {
        _updateState(AsyncTextButtonState.idle);
        _showError(error);
      },
      (_) {
        _updateState(AsyncTextButtonState.idle);
        widget.onSuccess?.call();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: TextButton(
        onPressed: switch (_state) {
          AsyncTextButtonState.idle => _handleTap,
          AsyncTextButtonState.loading => null,
        },
        child: switch (_state) {
          AsyncTextButtonState.loading => SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          AsyncTextButtonState.idle => Text(
            widget.text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        },
      ),
    );
  }
}
