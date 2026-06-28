import 'package:flutter/material.dart';
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
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ConfirmLnurlSendScreen extends StatefulWidget {
  final ConduitClient client;
  final Bolt11InvoiceWrapper invoice;
  final int amountSats;
  final LnSendFees fees;
  final String? contactName;

  const ConfirmLnurlSendScreen({
    super.key,
    required this.client,
    required this.invoice,
    required this.amountSats,
    required this.fees,
    this.contactName,
  });

  @override
  State<ConfirmLnurlSendScreen> createState() => _ConfirmLnurlSendScreenState();
}

class _ConfirmLnurlSendScreenState extends State<ConfirmLnurlSendScreen> {
  Future<void> _handleConfirm() async {
    await requireBiometricAuth(context);

    await widget.client.lnSend(
      invoice: widget.invoice,
      gateway: widget.fees.gatewayUrl,
    );

    if (!mounted) return;

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.contactName ?? 'Send Lightning')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
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
                        '${NumberFormat('#,###').format(widget.fees.feeSats)} sat · ${(widget.fees.feeSats / widget.amountSats * 100).toStringAsFixed(1)}%',
                  ),
                ],
              ),
              const Spacer(),
              AsyncButton(text: 'Confirm', onPressed: _handleConfirm),
            ],
          ),
        ),
      ),
    );
  }
}
