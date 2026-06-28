import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';

class GroupedList<T> extends StatelessWidget {
  final List<T> items;
  final String Function(T) groupKey;
  final Widget Function(BuildContext, T) itemBuilder;
  final Widget? header;

  const GroupedList({
    super.key,
    required this.items,
    required this.groupKey,
    required this.itemBuilder,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    final offset = header != null ? 1 : 0;

    return ListView.builder(
      // Full-bleed rows: no horizontal padding on the list. The header manages
      // its own padding (top included) and rows carry their content padding.
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: items.length + offset,
      itemBuilder: (context, index) {
        // The header runs full-bleed; it manages its own horizontal padding.
        if (index < offset) {
          return header!;
        }

        final itemIndex = index - offset;
        final key = groupKey(items[itemIndex]);
        final isFirst = itemIndex == 0 || key != groupKey(items[itemIndex - 1]);

        final row = itemBuilder(context, items[itemIndex]);

        if (!isFirst) return row;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                top: itemIndex == 0 ? 0 : 16,
                bottom: 8,
              ),
              child: Text(key, style: mediumStyle),
            ),
            row,
          ],
        );
      },
    );
  }
}
