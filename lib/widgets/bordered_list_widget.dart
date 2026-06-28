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
    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}
