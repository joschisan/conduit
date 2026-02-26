import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/screens/confirm_recovery_phrase_screen.dart';

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
      subset = wordList().where((word) => word.startsWith(query)).toList();
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Enter Word...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: _updateSearch,
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: subset.length,
              itemBuilder: (context, index) {
                final word = subset[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 4.0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: SizedBox(
                      width: 40,
                      child: Text(
                        '$currentWordNumber',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 32,
                        ),
                      ),
                    ),
                    title: Text(
                      word,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () => _selectWord(word),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
