import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/screens/confirm_recovery_phrase_screen.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/widgets/grouped_list_widget.dart';
import 'package:conduit/widgets/search_field_widget.dart';

class InputRecoveryPhraseScreen extends StatefulWidget {
  final DatabaseWrapper db;
  final List<String> partialSeedPhrase;

  const InputRecoveryPhraseScreen({
    super.key,
    required this.db,
    required this.partialSeedPhrase,
  });

  @override
  State<InputRecoveryPhraseScreen> createState() =>
      _InputRecoveryPhraseScreenState();
}

class _InputRecoveryPhraseScreenState extends State<InputRecoveryPhraseScreen> {
  String query = '';
  List<String> subset = wordList();

  int get currentWordNumber => widget.partialSeedPhrase.length + 1;

  void _updateSearch(String query) {
    setState(() {
      subset =
          wordList()
              .where((word) => word.contains(query.toLowerCase()))
              .toList();
    });
  }

  void _selectWord(String word) {
    final updatedPhrase = [...widget.partialSeedPhrase, word];

    if (updatedPhrase.length == 12) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => ConfirmRecoveryPhraseScreen(
                db: widget.db,
                seedPhrase: updatedPhrase,
              ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => InputRecoveryPhraseScreen(
                db: widget.db,
                partialSeedPhrase: updatedPhrase,
              ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Enter Word $currentWordNumber of 12')),
      body: GroupedList<String>(
        header: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SearchField(autofocus: true, onChanged: _updateSearch),
        ),
        items: subset,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        groupKey: (word) => word[0].toUpperCase(),
        itemBuilder:
            (context, word) => ListTile(
              contentPadding: listTilePadding,
              leading: SizedBox(
                width: 28,
                child: Text(
                  '$currentWordNumber',
                  textAlign: TextAlign.center,
                  style: largeStyle.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              title: Text(word, style: mediumStyle),
              onTap: () => _selectWord(word),
            ),
      ),
    );
  }
}
