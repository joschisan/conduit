import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/bridge_generated.dart/lnurl.dart';
import 'package:conduit/utils/async_button_mixin.dart';
import 'package:conduit/screens/lnurl_amount_screen.dart';
import 'package:conduit/screens/contact_name_entry_screen.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/widgets/search_field_widget.dart';
import 'package:conduit/widgets/grouped_list_widget.dart';
import 'package:conduit/widgets/loading_icon_widget.dart';

class _ContactTile extends StatefulWidget {
  final ConduitContact contact;
  final Future<void> Function() onTap;
  final VoidCallback onLongPress;

  const _ContactTile({
    required this.contact,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_ContactTile> createState() => _ContactTileState();
}

class _ContactTileState extends State<_ContactTile> with AsyncButtonMixin {
  @override
  Future<void> Function() get onPressed => widget.onTap;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      PhosphorIconsRegular.lightning,
      size: mediumIconSize,
      color: Theme.of(context).colorScheme.primary,
    );

    return ListTile(
      contentPadding: listTilePadding,
      leading: switch (buttonState) {
        AsyncButtonState.idle => icon,
        AsyncButtonState.loading => LoadingIcon(icon: icon),
      },
      title: Text(widget.contact.name, style: mediumStyle),
      onTap: switch (buttonState) {
        AsyncButtonState.idle => handlePress,
        AsyncButtonState.loading => null,
      },
      onLongPress: widget.onLongPress,
    );
  }
}

class DisplayContactsScreen extends StatefulWidget {
  final ConduitClient client;
  final ConduitClientFactory clientFactory;

  const DisplayContactsScreen({
    super.key,
    required this.client,
    required this.clientFactory,
  });

  @override
  State<DisplayContactsScreen> createState() => _DisplayContactsScreenState();
}

class _DisplayContactsScreenState extends State<DisplayContactsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  List<ConduitContact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final contacts = await widget.clientFactory.listContacts();
    if (!mounted) return;
    setState(() {
      _contacts = contacts;
    });
  }

  List<ConduitContact> get _filteredContacts {
    return _contacts.where((c) => c.matchQuery(query: _query)).toList();
  }

  Future<void> _handleContactTap(ConduitContact contact) async {
    final payResponse = await lnurlFetchLimits(lnurl: contact.lnurl);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder:
            (_) => LnurlAmountScreen(
              client: widget.client,
              clientFactory: widget.clientFactory,
              lnurl: contact.lnurl,
              payResponse: payResponse,
              contactName: contact.name,
            ),
      ),
    );
  }

  Future<void> _handleEditContact(ConduitContact contact) async {
    await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder:
            (_) => ContactNameEntryScreen(
              clientFactory: widget.clientFactory,
              lnurl: contact.lnurl,
              initialName: contact.name,
              onDelete: () async {
                await widget.clientFactory.deleteContact(lnurl: contact.lnurl);
              },
            ),
      ),
    );

    if (mounted) {
      _loadContacts();
    }
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'You have no contacts yet.',
            textAlign: TextAlign.center,
            style: smallStyle.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredContacts;

    return Scaffold(
      appBar: AppBar(title: const Text('Lightning Contacts')),
      body: SafeArea(
        child: Column(
          children: [
            if (_contacts.isEmpty) _buildEmptyState(),
            if (_contacts.isNotEmpty)
              Expanded(
                child: GroupedList<ConduitContact>(
                  header: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SearchField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  items: filtered,
                  groupKey: (contact) => contact.name[0].toUpperCase(),
                  itemBuilder:
                      (context, contact) => _ContactTile(
                        contact: contact,
                        onTap: () => _handleContactTap(contact),
                        onLongPress: () => _handleEditContact(contact),
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
