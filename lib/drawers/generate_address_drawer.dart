import 'package:flutter/material.dart';
import 'package:conduit/widgets/drawer_shell.dart';
import 'package:conduit/widgets/async_action_button.dart';
import 'package:conduit/utils/drawer_utils.dart';

class GenerateAddressDrawer extends StatelessWidget {
  final VoidCallback onConfirm;

  const GenerateAddressDrawer({super.key, required this.onConfirm});

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onConfirm,
  }) {
    return DrawerUtils.show(
      context: context,
      child: GenerateAddressDrawer(onConfirm: onConfirm),
    );
  }

  void _handleConfirm(BuildContext context) {
    Navigator.of(context).pop();
    onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    return DrawerShell(
      icon: Icons.add,
      title: 'Generate New Bitcoin Address?',
      children: [
        AsyncActionButton(
          text: 'Confirm',
          onPressed: () async => _handleConfirm(context),
        ),
      ],
    );
  }
}
