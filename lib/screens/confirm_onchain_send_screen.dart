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
import 'package:conduit/widgets/shareable_row_widget.dart';
import 'package:conduit/utils/auth_utils.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ConfirmOnchainSendScreen extends StatefulWidget {
  final ConduitClient client;
  final BitcoinAddressWrapper address;
  final int amountSats;
  final int feeSats;

  const ConfirmOnchainSendScreen({
    super.key,
    required this.client,
    required this.address,
    required this.amountSats,
    required this.feeSats,
  });

  @override
  State<ConfirmOnchainSendScreen> createState() =>
      _ConfirmOnchainSendScreenState();
}

class _ConfirmOnchainSendScreenState extends State<ConfirmOnchainSendScreen> {
  Future<void> _handleConfirm() async {
    await requireBiometricAuth(context);

    await widget.client.onchainSend(
      address: widget.address,
      amountSats: widget.amountSats,
    );

    if (!mounted) return;

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Onchain')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: BleedColumn(
            children: [
              BorderedList.column(
                children: [
                  const PaymentSummaryRow(
                    paymentType: PaymentType.bitcoin,
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
                        '${NumberFormat('#,###').format(widget.feeSats)} sat · ${(widget.feeSats / widget.amountSats * 100).toStringAsFixed(1)}%',
                    iconColor:
                        widget.feeSats > widget.amountSats * 0.02
                            ? Colors.amber
                            : null,
                  ),
                  ShareableRow(
                    data: widget.address.toString(),
                    label: 'Bitcoin Address',
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
