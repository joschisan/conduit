import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/bridge_generated.dart/lnurl.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/widgets/text_entry_body_widget.dart';

class ContactNameEntryScreen extends StatefulWidget {
  final ConduitClientFactory clientFactory;
  final LnurlWrapper lnurl;
  final String? initialName;
  final Future<void> Function()? onDelete;

  const ContactNameEntryScreen({
    super.key,
    required this.clientFactory,
    required this.lnurl,
    this.initialName,
    this.onDelete,
  });

  @override
  State<ContactNameEntryScreen> createState() => _ContactNameEntryScreenState();
}

class _ContactNameEntryScreenState extends State<ContactNameEntryScreen> {
  late final _controller = TextEditingController(text: widget.initialName);
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    final name = _controller.text.trim();

    if (name.isEmpty) {
      throw 'Please enter a name';
    }

    await widget.clientFactory.saveContact(lnurl: widget.lnurl, name: name);

    if (!mounted) return;

    Navigator.of(context).pop(name);
  }

  Future<void> _handleDelete() async {
    await widget.onDelete!();

    if (!mounted) return;

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Contact Name'),
        actions: [
          if (widget.onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: smallIconSize),
              onPressed: _handleDelete,
            ),
        ],
      ),
      body: TextEntryBody(
        controller: _controller,
        focusNode: _focusNode,
        onConfirm: _handleConfirm,
        keyboardType: TextInputType.name,
        textCapitalization: TextCapitalization.words,
      ),
    );
  }
}
