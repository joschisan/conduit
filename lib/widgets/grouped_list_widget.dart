import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';

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
      padding: const EdgeInsets.all(16).copyWith(bottom: 32),
      itemCount: items.length + offset,
      itemBuilder: (context, index) {
        if (index < offset) return header!;

        final itemIndex = index - offset;
        final key = groupKey(items[itemIndex]);
        final isFirst = itemIndex == 0 || key != groupKey(items[itemIndex - 1]);
        final isLast =
            itemIndex == items.length - 1 ||
            key != groupKey(items[itemIndex + 1]);

        final decorated = BorderedList.decorateItem(
          context: context,
          child: itemBuilder(context, items[itemIndex]),
          isFirst: isFirst,
          isLast: isLast,
        );

        if (!isFirst) return decorated;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(
                left: 8,
                top: itemIndex == 0 ? 0 : 16,
                bottom: 8,
              ),
              child: Text(key, style: mediumStyle),
            ),
            decorated,
          ],
        );
      },
    );
  }
}
