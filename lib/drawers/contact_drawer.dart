import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/bridge_generated.dart/lnurl.dart';
import 'package:conduit/utils/drawer_utils.dart';
import 'package:conduit/utils/notification_utils.dart';

class ContactDrawer extends StatefulWidget {
  final ConduitClientFactory clientFactory;
  final LnurlWrapper lnurl;
  final String? contactName;
  final VoidCallback? onDelete;

  const ContactDrawer({
    super.key,
    required this.clientFactory,
    required this.lnurl,
    this.contactName,
    this.onDelete,
  });

  static Future<String?> show(
    BuildContext context, {
    required ConduitClientFactory clientFactory,
    required LnurlWrapper lnurl,
    String? contactName,
    VoidCallback? onDelete,
  }) {
    return DrawerUtils.show<String?>(
      context: context,
      child: ContactDrawer(
        clientFactory: clientFactory,
        lnurl: lnurl,
        contactName: contactName,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<ContactDrawer> createState() => _ContactDrawerState();
}

class _ContactDrawerState extends State<ContactDrawer> {
  late final _nameController = TextEditingController(text: widget.contactName);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      NotificationUtils.showError(context, 'Name is empty');
      return;
    }

    await widget.clientFactory.saveContact(lnurl: widget.lnurl, name: name);

    if (!mounted) return;

    Navigator.of(context).pop(name);
  }

  void _handleDelete() {
    Navigator.of(context).pop();
    widget.onDelete!();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: TextField(
          controller: _nameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Contact Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon:
                widget.onDelete != null
                    ? IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _handleDelete,
                    )
                    : null,
            suffixIcon: IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: _handleSave,
            ),
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) => _handleSave(),
        ),
      ),
    );
  }
}
