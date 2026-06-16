import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/widgets/async_button_widget.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/detail_row_widget.dart';
import 'package:conduit/widgets/shareable_row_widget.dart';
import 'package:conduit/widgets/warning_card_widget.dart';
import 'package:conduit/utils/auth_utils.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ConfirmLnurlSendScreen extends StatefulWidget {
  final ConduitClient client;
  final Bolt11InvoiceWrapper invoice;
  final int amountSats;
  final LnSendFees fees;
  final ({String name, String amount})? fiatAmount;
  final String? contactName;

  const ConfirmLnurlSendScreen({
    super.key,
    required this.client,
    required this.invoice,
    required this.amountSats,
    required this.fees,
    this.fiatAmount,
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
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              BorderedList.column(
                children: [
                  if (widget.contactName != null)
                    DetailRow(
                      icon: PhosphorIconsRegular.user,
                      label: 'Contact',
                      value: widget.contactName!,
                    ),
                  DetailRow(
                    icon: PhosphorIconsRegular.currencyBtc,
                    label: 'Amount in Bitcoin',
                    value:
                        '${NumberFormat('#,###').format(widget.amountSats)} sat',
                  ),
                  if (widget.fiatAmount != null)
                    DetailRow(
                      icon: PhosphorIconsRegular.currencyDollar,
                      label: 'Amount in ${widget.fiatAmount!.name}',
                      value: widget.fiatAmount!.amount,
                    ),
                  ShareableRow(data: widget.fees.gatewayUrl, label: 'Gateway'),
                  DetailRow(
                    icon: PhosphorIconsRegular.network,
                    label: 'Network Fee',
                    value:
                        '${NumberFormat('#,###').format(widget.fees.feeSats)} sat · ${widget.fees.isDirect ? 'direct' : 'lightning'}',
                  ),
                ],
              ),
              const Spacer(),
              if (widget.fees.feeSats > widget.amountSats * 0.02) ...[
                WarningCard(
                  icon: PhosphorIconsRegular.warning,
                  text:
                      'High Relative Fee of ${(widget.fees.feeSats / widget.amountSats * 100).toStringAsFixed(1)}%',
                ),
                const SizedBox(height: 16),
              ],
              AsyncButton(text: 'Confirm', onPressed: _handleConfirm),
            ],
          ),
        ),
      ),
    );
  }
}
