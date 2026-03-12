import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/bridge_generated.dart/lnurl.dart';
import 'package:conduit/widgets/async_button_mixin.dart';
import 'package:conduit/screens/lnurl_payment_amount_screen.dart';
import 'package:conduit/drawers/lightning_payment_drawer.dart';
import 'package:conduit/drawers/delete_contact_drawer.dart';

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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(
          Icons.person,
          size: 32,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(widget.contact.name),
        trailing: switch (buttonState) {
          AsyncButtonState.loading => const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          AsyncButtonState.idle => null,
        },
        onTap: switch (buttonState) {
          AsyncButtonState.idle => handlePress,
          AsyncButtonState.loading => null,
        },
        onLongPress: widget.onLongPress,
      ),
    );
  }
}

class ContactsScreen extends StatefulWidget {
  final ConduitClient client;
  final ConduitClientFactory clientFactory;

  const ContactsScreen({
    super.key,
    required this.client,
    required this.clientFactory,
  });

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> with AsyncButtonMixin {
  final _searchController = TextEditingController();
  String _query = '';
  List<ConduitContact> _contacts = [];

  @override
  Future<void> Function() get onPressed => _handleContinue;

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
    final payInfo = await lnurlFetchLimits(lnurl: contact.lnurl);

    if (!mounted) return;

    if (payInfo.minSats == payInfo.maxSats) {
      final invoice = await lnurlResolve(
        payInfo: payInfo,
        amountSats: payInfo.minSats,
      );

      if (!mounted) return;

      LightningPaymentDrawer.show(
        context,
        client: widget.client,
        invoice: invoice,
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (_) => LnurlPaymentAmountScreen(
                client: widget.client,
                clientFactory: widget.clientFactory,
                lnurl: contact.lnurl,
                payInfo: payInfo,
                contactName: contact.name,
              ),
        ),
      );
    }
  }

  Future<void> _handleContinue() async {
    final lnurl = parseLnurl(request: _query);

    if (lnurl == null) {
      throw 'Invalid Lightning Url';
    }

    final payInfo = await lnurlFetchLimits(lnurl: lnurl);

    if (!mounted) return;

    final contactName = await widget.clientFactory.getContactName(lnurl: lnurl);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder:
            (_) => LnurlPaymentAmountScreen(
              client: widget.client,
              clientFactory: widget.clientFactory,
              lnurl: lnurl,
              payInfo: payInfo,
              contactName: contactName,
            ),
      ),
    );
  }

  Future<void> _handleDeleteContact(ConduitContact contact) async {
    await DeleteContactDrawer.show(
      context,
      contact: contact,
      clientFactory: widget.clientFactory,
      onSuccess: _loadContacts,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredContacts;

    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search or enter lightning address...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: switch (buttonState) {
                    AsyncButtonState.idle => IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: handlePress,
                    ),
                    AsyncButtonState.loading => const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  },
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            if (_contacts.isEmpty)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: Text(
                    'Create contacts by assigning a name to a Lightning Url or Address.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            if (_contacts.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final contact = filtered[index];
                    return _ContactTile(
                      contact: contact,
                      onTap: () => _handleContactTap(contact),
                      onLongPress: () => _handleDeleteContact(contact),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
