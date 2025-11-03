import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/screens/confirm_seed_screen.dart';

class InputSeedScreen extends StatefulWidget {
  final DatabaseWrapper db;
  final List<String> partialSeedPhrase;

  const InputSeedScreen({
    super.key,
    required this.db,
    required this.partialSeedPhrase,
  });

  @override
  State<InputSeedScreen> createState() => _InputSeedScreenState();
}

class _InputSeedScreenState extends State<InputSeedScreen> {
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
              (context) =>
                  ConfirmSeedScreen(db: widget.db, seedPhrase: updatedPhrase),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => InputSeedScreen(
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
      appBar: AppBar(title: Text('Enter word $currentWordNumber of 12')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search for word...',
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
              itemCount: subset.length,
              itemBuilder: (context, index) {
                final word = subset[index];
                return ListTile(
                  title: Text(word),
                  onTap: () => _selectWord(word),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
