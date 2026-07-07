import 'package:flutter/material.dart';
import 'package:conduit/widgets/scrollable_body_widget.dart';
import 'package:intl/intl.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/events.dart';
import 'package:conduit/widgets/async_button_widget.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/bleed_column_widget.dart';
import 'package:conduit/widgets/payment_summary_row_widget.dart';
import 'package:conduit/widgets/detail_row_widget.dart';
import 'package:conduit/widgets/amount_rows.dart';
import 'package:conduit/utils/auth_utils.dart';
import 'package:conduit/utils/notification_utils.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Confirms an lnurl payment. The gateway is selected and its fee quoted as
/// soon as the screen opens; the fee row shows a spinner until the quote
/// arrives and the confirm button stays disabled without one. A failed quote
/// pops the screen and surfaces an error notification. The quoted gateway is
/// passed to [ConduitClient.lnSend] so the fee shown here matches what is
/// charged.
class ConfirmLnurlSendScreen extends StatefulWidget {
  final ConduitClient client;
  final Bolt11InvoiceWrapper invoice;
  final int amountSats;
  final String? contactName;

  const ConfirmLnurlSendScreen({
    super.key,
    required this.client,
    required this.invoice,
    required this.amountSats,
    this.contactName,
  });

  @override
  State<ConfirmLnurlSendScreen> createState() => _ConfirmLnurlSendScreenState();
}

class _ConfirmLnurlSendScreenState extends State<ConfirmLnurlSendScreen> {
  LnSendFees? _fees;

  @override
  void initState() {
    super.initState();
    _loadFees();
  }

  Future<void> _loadFees() async {
    try {
      final fees = await widget.client.lnCalculateFees(invoice: widget.invoice);

      if (!mounted) return;

      setState(() => _fees = fees);
    } catch (error) {
      if (!mounted) return;

      Navigator.of(context).pop();
      NotificationUtils.showError(context, error.toString());
    }
  }

  Future<void> _handleConfirm(LnSendFees fees) async {
    await requireBiometricAuth(context);

    await widget.client.lnSend(
      invoice: widget.invoice,
      gateway: fees.gatewayUrl,
    );

    if (!mounted) return;

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final fees = _fees;

    return Scaffold(
      appBar: AppBar(title: Text(widget.contactName ?? 'Send Lightning')),
      body: ScrollableBody(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: BleedColumn(
            children: [
              BorderedList.column(
                children: [
                  const PaymentSummaryRow(
                    paymentType: PaymentType.lightning,
                    incoming: false,
                    status: 'Send',
                  ),
                  ...amountRows(
                    client: widget.client,
                    amountSats: widget.amountSats,
                  ),
                  DetailRow(
                    icon: PhosphorIconsRegular.network,
                    label: 'Network Fee',
                    value:
                        fees == null
                            ? null
                            : '${NumberFormat('#,###').format(fees.feeSats)} sat · ${NumberFormat('#,##0.#').format(fees.feeSats / widget.amountSats * 100)}%',
                  ),
                ],
              ),
              const Spacer(),
              AsyncButton(
                text: 'Confirm',
                enabled: fees != null,
                onPressed: () => _handleConfirm(fees!),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
