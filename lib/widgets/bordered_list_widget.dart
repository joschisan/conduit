import 'package:flutter/material.dart';

/// A full-bleed list: rows run edge-to-edge with no outer border or dividers.
class BorderedList extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const BorderedList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.shrinkWrap = false,
    this.physics,
  });

  factory BorderedList.column({Key? key, required List<Widget> children}) {
    return BorderedList(
      key: key,
      itemCount: children.length,
      itemBuilder: (_, index) => children[index],
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A non-scrolling shrink-wrapped list is just a column. Building it as
    // one lets ancestors probe intrinsic sizes (e.g. IntrinsicHeight), which
    // a ListView's viewport cannot answer. Stretch mirrors the tight
    // cross-axis constraint a ListView imposes on its rows.
    if (shrinkWrap && physics is NeverScrollableScrollPhysics) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (var i = 0; i < itemCount; i++) itemBuilder(context, i)],
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}
