import 'package:flutter/material.dart';

class RecoveryPhraseGrid extends StatelessWidget {
  final List<String> words;

  const RecoveryPhraseGrid({super.key, required this.words});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final half = words.length ~/ 2;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildColumn(theme, words.sublist(0, half), 0)),
        const SizedBox(width: 16),
        Expanded(child: _buildColumn(theme, words.sublist(half), half)),
      ],
    );
  }

  Widget _buildColumn(ThemeData theme, List<String> columnWords, int offset) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < columnWords.length; i++)
          Card(
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
                  '${offset + i + 1}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                  ),
                ),
              ),
              title: Text(
                columnWords[i],
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
