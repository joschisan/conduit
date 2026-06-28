import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/screens/base_screen.dart';
import 'package:conduit/widgets/async_button_widget.dart';
import 'package:conduit/utils/notification_utils.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/utils/number_utils.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/bleed_column_widget.dart';
import 'package:conduit/widgets/icon_chip_widget.dart';

class ConfirmRecoveryPhraseScreen extends StatelessWidget {
  final DatabaseWrapper db;
  final List<String> seedPhrase;

  const ConfirmRecoveryPhraseScreen({
    super.key,
    required this.db,
    required this.seedPhrase,
  });

  Future<void> _recoverWallet(BuildContext context) async {
    final mnemonic = await parseMnemonic(words: seedPhrase);

    if (mnemonic == null) {
      if (context.mounted) {
        NotificationUtils.showError(context, 'Failed to parse recovery phrase');
      }
      return;
    }

    final clientFactory = await ConduitClientFactory.init(
      db: db,
      mnemonic: mnemonic,
    );

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => BaseScreen(clientFactory: clientFactory),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Recovery Phrase')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
        child: BleedColumn(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BorderedList.column(
              children: [
                for (int i = 0; i < seedPhrase.length; i++)
                  ListTile(
                    contentPadding: listTilePadding,
                    leading: const IconChip(icon: PhosphorIconsRegular.key),
                    // Stack word/number in the title (not subtitle) to keep the
                    // tile's single-line height instead of growing to two-line.
                    title: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(seedPhrase[i], style: mediumStyle),
                        Text(
                          spellOutNumber(i + 1),
                          style: smallStyle.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            AsyncButton(
              text: 'Confirm',
              onPressed: () => _recoverWallet(context),
            ),
          ],
        ),
      ),
    );
  }
}
