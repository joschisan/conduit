import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/screens/base_screen.dart';
import 'package:conduit/widgets/async_button_widget.dart';
import 'package:conduit/utils/notification_utils.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';

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
        padding: const EdgeInsets.all(16).copyWith(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < seedPhrase.length; i++)
              BorderedList.decorateItem(
                context: context,
                isFirst: i == 0,
                isLast: i == seedPhrase.length - 1,
                child: ListTile(
                  contentPadding: listTilePadding,
                  leading: PhosphorIcon(
                    PhosphorIconsRegular.key,
                    color: theme.colorScheme.primary,
                    size: mediumIconSize,
                  ),
                  title: Text('${i + 1} - ${seedPhrase[i]}', style: mediumStyle),
                ),
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
