import 'package:flutter/material.dart';
import 'package:conduit/widgets/drawer_shell_widget.dart';
import 'package:conduit/widgets/async_button_widget.dart';
import 'package:conduit/utils/drawer_utils.dart';

class GenerateOnchainAddressDrawer extends StatelessWidget {
  final VoidCallback onConfirm;

  const GenerateOnchainAddressDrawer({super.key, required this.onConfirm});

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onConfirm,
  }) {
    return DrawerUtils.show(
      context: context,
      child: GenerateOnchainAddressDrawer(onConfirm: onConfirm),
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
      title: 'Generate Onchain Address?',
      children: [
        AsyncButton(
          text: 'Confirm',
          onPressed: () async => _handleConfirm(context),
        ),
      ],
    );
  }
}
