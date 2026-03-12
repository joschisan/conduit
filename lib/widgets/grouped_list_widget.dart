import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';

class GroupedList<T> extends StatelessWidget {
  final List<T> items;
  final String Function(T) groupKey;
  final Widget Function(BuildContext, T) itemBuilder;
  final EdgeInsets padding;

  const GroupedList({
    super.key,
    required this.items,
    required this.groupKey,
    required this.itemBuilder,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final key = groupKey(items[index]);
        final isFirst = index == 0 || key != groupKey(items[index - 1]);
        final isLast =
            index == items.length - 1 || key != groupKey(items[index + 1]);

        final decorated = BorderedList.decorateItem(
          context: context,
          child: itemBuilder(context, items[index]),
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
                top: index == 0 ? 0 : 16,
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
