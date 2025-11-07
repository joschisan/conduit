import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart' hide State;
import 'package:intl/intl.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/widgets/amount_display.dart';
import 'package:conduit/widgets/transactions_list.dart';
import 'package:conduit/widgets/multi_scanner_widget.dart';
import 'package:conduit/screens/amount_screen.dart';
import 'package:conduit/screens/display_invoice_screen.dart';
import 'package:conduit/screens/display_ecash_screen.dart';
import 'package:conduit/utils/notification_utils.dart';
import 'package:conduit/utils/fp_utils.dart';
import 'package:conduit/utils/auth_utils.dart';
import 'package:conduit/utils/drawer_utils.dart';

class HomeScreen extends StatefulWidget {
  final FClient client;

  const HomeScreen({super.key, required this.client});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late Future<List<FTransaction>> _transactionsFuture;

  @override
  void initState() {
    super.initState();
    _transactionsFuture = _loadTransactions();

    widget.client.subscribeBalance().listen((_) {
      // Balance changed, reload transactions
      setState(() {
        _transactionsFuture = _loadTransactions();
      });
    });
  }

  Future<List<FTransaction>> _loadTransactions() async {
    switch (_currentIndex) {
      case 0:
        return await widget.client.lnv2TransactionHistory();
      case 1:
        return await widget.client.mintTransactionHistory();
      default:
        return [];
    }
  }

  void _onCreateInvoice() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => AmountScreen(
              client: widget.client,
              onAmountSubmitted: _handleCreateInvoice,
              showLnurlButton: true,
            ),
      ),
    );
  }

  void _onSendEcash() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => AmountScreen(
              client: widget.client,
              onAmountSubmitted: _handleSendEcash,
            ),
      ),
    );
  }

  void _onFabPressed() {
    switch (_currentIndex) {
      case 0:
        _onCreateInvoice();
        break;
      case 1:
        _onSendEcash();
        break;
    }
  }

  TaskEither<String, void> _handleCreateInvoice(
    int amountSats,
    BuildContext context,
    FClient client,
  ) {
    return safeTask(() async {
      final invoice = await client.lnReceive(amountSat: amountSats);

      if (!context.mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (_) => DisplayInvoiceScreen(
                invoice: invoice,
                amount: amountSats,
                description: '',
              ),
        ),
      );
    });
  }

  TaskEither<String, void> _handleSendEcash(
    int amountSats,
    BuildContext context,
    FClient client,
  ) {
    return safeTask(() async {
      final authenticated = await requireBiometricAuth(
        context,
        'Please authenticate to send eCash',
      );

      if (!authenticated) {
        throw Exception('Authentication required');
      }

      final ecashNotes = await client.ecashSend(amountSat: amountSats);

      final notes = parseOobNotes(notes: ecashNotes);

      if (notes == null) {
        throw Exception('Failed to parse ecash notes');
      }

      final encoder = await OobNotesEncoder.newInstance(notes: notes);

      if (!context.mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (_) => DisplayEcashScreen(
                encoder: encoder,
                ecashNotes: ecashNotes,
                amount: amountSats,
              ),
        ),
      );
    });
  }

  void _onScan() {
    showStandardDrawer(
      context: context,
      child: MultiScannerWidget(
        client: widget.client,
        onLightningPayment: _handleLightningPayment,
        onEcashRedeem: _handleEcashRedeem,
        onLnurlDetected: _handleLnurlDetected,
        onLightningPaymentSuccess: () => Navigator.of(context).pop(),
        onEcashRedeemSuccess: () => Navigator.of(context).pop(),
      ),
    );
  }

  TaskEither<String, void> _handleLightningPayment(
    Bolt11InvoiceWrapper invoice,
  ) {
    return safeTask(() async {
      final authenticated = await requireBiometricAuth(
        context,
        'Please authenticate to send payment',
      );

      if (!authenticated) {
        throw Exception('Authentication required');
      }

      await widget.client.lnSend(invoice: invoice);

      NotificationUtils.showSuccess(context, 'Payment sent!');
    });
  }

  TaskEither<String, void> _handleEcashRedeem(OobNotesWrapper ecash) {
    return safeTask(() async {
      await widget.client.ecashReceive(notes: ecash);

      NotificationUtils.showSuccess(context, 'eCash received!');
    });
  }

  void _handleLnurlDetected(LnurlWrapper lnurl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => AmountScreen(
              client: widget.client,
              onAmountSubmitted:
                  (amountSats, context, client) =>
                      _handleLnurlPayment(lnurl, amountSats, context, client),
            ),
      ),
    );
  }

  TaskEither<String, void> _handleLnurlPayment(
    LnurlWrapper lnurl,
    int amountSats,
    BuildContext context,
    FClient client,
  ) {
    return safeTask(() async {
      // Resolve LNURL to get invoice
      final invoice = await resolveLnurl(lnurl: lnurl, amountSats: amountSats);

      if (!context.mounted) return;

      // Require biometric authentication
      final authenticated = await requireBiometricAuth(
        context,
        'Please authenticate to send payment',
      );

      if (!authenticated) {
        throw Exception('Authentication required');
      }

      await client.lnSend(invoice: invoice);

      NotificationUtils.showSuccess(context, 'Payment sent!');

      if (!context.mounted) return;

      Navigator.of(context).pop();
    });
  }

  void _showTransactionDetails(FTransaction tx) {
    showStandardDrawer(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                child: Icon(
                  tx.incoming ? Icons.arrow_downward : Icons.arrow_upward,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDateTime(tx.timestamp),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),
              if (tx.oob != null)
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: tx.oob!));
                    NotificationUtils.showCopy(context, 'Copied to clipboard!');
                  },
                  icon: const Icon(Icons.copy),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: AmountDisplay(tx.amountSats),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

    return DateFormat('MMM dd, HH:mm:ss').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _onScan,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onFabPressed,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            StreamBuilder<int>(
              stream: widget.client.subscribeBalance(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return AmountDisplay(snapshot.data!);
                } else {
                  return const CircularProgressIndicator();
                }
              },
            ),
            const SizedBox(height: 24),
            Expanded(
              child: FutureBuilder<List<FTransaction>>(
                key: ValueKey(_currentIndex),
                future: _transactionsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading transactions',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    );
                  }

                  return TransactionsList(
                    transactions: snapshot.data ?? [],
                    onTransactionTap: _showTransactionDetails,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            _transactionsFuture = _loadTransactions();
          });
        },
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.flash_on),
            label: 'Lightning',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.currency_bitcoin),
            label: 'eCash',
          ),
        ],
      ),
    );
  }
}
