import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/bridge_generated.dart/lnurl.dart';
import 'package:conduit/utils/drawer_utils.dart';
import 'package:conduit/utils/notification_utils.dart';

class SaveContactDrawer extends StatefulWidget {
  final ConduitClientFactory clientFactory;
  final LnurlWrapper lnurl;
  final String? contactName;

  const SaveContactDrawer({
    super.key,
    required this.clientFactory,
    required this.lnurl,
    this.contactName,
  });

  static Future<String?> show(
    BuildContext context, {
    required ConduitClientFactory clientFactory,
    required LnurlWrapper lnurl,
    String? contactName,
  }) {
    return DrawerUtils.show<String?>(
      context: context,
      child: SaveContactDrawer(
        clientFactory: clientFactory,
        lnurl: lnurl,
        contactName: contactName,
      ),
    );
  }

  @override
  State<SaveContactDrawer> createState() => _SaveContactDrawerState();
}

class _SaveContactDrawerState extends State<SaveContactDrawer> {
  late final _nameController = TextEditingController(text: widget.contactName);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      NotificationUtils.showError(context, 'Please enter a Name');
      return;
    }

    await widget.clientFactory.saveContact(lnurl: widget.lnurl, name: name);

    if (!mounted) return;

    Navigator.of(context).pop(name);
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
