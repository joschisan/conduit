import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';

class DrawerUtils {
  DrawerUtils._();

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: cornerRadiusValue),
      ),
      builder: (_) => child,
    );
  }

  /// Pops the current drawer and pushes a new screen.
  /// Common pattern for drawer actions that navigate to a full screen.
  static void popAndPush(BuildContext context, Widget screen) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}
