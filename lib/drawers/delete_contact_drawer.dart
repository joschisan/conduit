import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/widgets/drawer_shell.dart';
import 'package:conduit/widgets/async_action_button.dart';
import 'package:conduit/utils/drawer_utils.dart';

class DeleteContactDrawer extends StatefulWidget {
  final ConduitContact contact;
  final ConduitClientFactory clientFactory;
  final VoidCallback onSuccess;

  const DeleteContactDrawer({
    super.key,
    required this.contact,
    required this.clientFactory,
    required this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required ConduitContact contact,
    required ConduitClientFactory clientFactory,
    required VoidCallback onSuccess,
  }) {
    return DrawerUtils.show(
      context: context,
      child: DeleteContactDrawer(
        contact: contact,
        clientFactory: clientFactory,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<DeleteContactDrawer> createState() => _DeleteContactDrawerState();
}

class _DeleteContactDrawerState extends State<DeleteContactDrawer> {
  Future<void> _handleDelete() async {
    await widget.clientFactory.deleteContact(lnurl: widget.contact.lnurl);

    if (!mounted) return;

    Navigator.of(context).pop();

    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    return DrawerShell(
      icon: Icons.delete_outline,
      title: 'Delete ${widget.contact.name}?',
      children: [AsyncActionButton(text: 'Confirm', onPressed: _handleDelete)],
    );
  }
}
