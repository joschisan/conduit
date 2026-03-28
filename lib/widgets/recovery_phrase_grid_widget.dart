import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';

class RecoveryPhraseGrid extends StatelessWidget {
  final List<String> words;

  const RecoveryPhraseGrid({super.key, required this.words});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outlineVariant;
    final half = words.length ~/ 2;

    return BorderedList.decorateItem(
      context: context,
      isFirst: true,
      isLast: true,
      child: Table(
        border: TableBorder.symmetric(
          inside: BorderSide(color: borderColor, width: 1),
        ),
        children: [
          for (int i = 0; i < half; i++)
            TableRow(
              children: [
                _buildCell(theme, i, words[i]),
                _buildCell(theme, half + i, words[half + i]),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCell(ThemeData theme, int index, String word) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.center,
              style: largeStyle.copyWith(color: theme.colorScheme.primary),
            ),
          ),
          const SizedBox(width: 8),
          Text(word, style: mediumStyle),
        ],
      ),
    );
  }
}
