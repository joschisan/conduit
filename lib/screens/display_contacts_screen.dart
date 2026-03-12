import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/bridge_generated.dart/lnurl.dart';
import 'package:conduit/utils/async_button_mixin.dart';
import 'package:conduit/screens/lnurl_amount_screen.dart';
import 'package:conduit/drawers/lightning_invoice_drawer.dart';
import 'package:conduit/drawers/edit_contact_drawer.dart';

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
        leading: switch (buttonState) {
          AsyncButtonState.idle => Icon(
            Icons.person,
            size: 32,
            color: Theme.of(context).colorScheme.primary,
          ),
          AsyncButtonState.loading => Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.person,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
        },
        title: Text(widget.contact.name),
        onTap: switch (buttonState) {
          AsyncButtonState.idle => handlePress,
          AsyncButtonState.loading => null,
        },
        onLongPress: widget.onLongPress,
      ),
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

class _DisplayContactsScreenState extends State<DisplayContactsScreen>
    with AsyncButtonMixin {
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
    final payResponse = await lnurlFetchLimits(lnurl: contact.lnurl);

    if (!mounted) return;

    if (payResponse.minSats == payResponse.maxSats) {
      final invoice = await lnurlResolve(
        payResponse: payResponse,
        amountSats: payResponse.minSats,
      );

      if (!mounted) return;

      LightningInvoiceDrawer.show(
        context,
        client: widget.client,
        invoice: invoice,
      );
    } else {
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
  }

  Future<void> _handleContinue() async {
    final lnurl = parseLnurl(request: _query);

    if (lnurl == null) {
      throw 'Failed to parse lightning url';
    }

    final payResponse = await lnurlFetchLimits(lnurl: lnurl);

    if (!mounted) return;

    final contactName = await widget.clientFactory.getContactName(lnurl: lnurl);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder:
            (_) => LnurlAmountScreen(
              client: widget.client,
              clientFactory: widget.clientFactory,
              lnurl: lnurl,
              payResponse: payResponse,
              contactName: contactName,
            ),
      ),
    );
  }

  Future<void> _handleEditContact(ConduitContact contact) async {
    final name = await EditContactDrawer.show(
      context,
      clientFactory: widget.clientFactory,
      lnurl: contact.lnurl,
      contactName: contact.name,
      onDelete: () async {
        await widget.clientFactory.deleteContact(lnurl: contact.lnurl);
        _loadContacts();
      },
    );

    if (mounted && name != null) {
      _loadContacts();
    }
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
                  hintText: 'Enter name or lightning address...',
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
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Contacts',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'To make recurring payments to the same recipient, create a contact by assigning a name to their lightning url or address.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
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
                      onLongPress: () => _handleEditContact(contact),
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
