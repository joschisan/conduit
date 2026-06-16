import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/widgets/drawer_shell_widget.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/detail_row_widget.dart';
import 'package:conduit/widgets/async_button_widget.dart';
import 'package:conduit/utils/drawer_utils.dart';

class EcashDrawer extends StatefulWidget {
  final ConduitClient client;
  final ECashWrapper notes;

  const EcashDrawer({super.key, required this.client, required this.notes});

  static Future<bool?> show(
    BuildContext context, {
    required ConduitClient client,
    required ECashWrapper notes,
  }) {
    return DrawerUtils.show<bool>(
      context: context,
      child: EcashDrawer(client: client, notes: notes),
    );
  }

  @override
  State<EcashDrawer> createState() => _EcashDrawerState();
}

class _EcashDrawerState extends State<EcashDrawer> {
  Future<void> _handleReceive() async {
    await widget.client.ecashReceive(notes: widget.notes);

    if (!mounted) return;

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DrawerShell(
      icon: PhosphorIconsRegular.coinVertical,
      title: 'Receive eCash',
      children: [
        BorderedList.column(
          children: [
            DetailRow(
              icon: PhosphorIconsRegular.currencyBtc,
              label: 'Amount in Bitcoin',
              value:
                  '${NumberFormat('#,###').format(widget.notes.amountSats())} sat',
            ),
          ],
        ),
        const SizedBox(height: 16),
        AsyncButton(text: 'Receive', onPressed: _handleReceive),
      ],
    );
  }
}
