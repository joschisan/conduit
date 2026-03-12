import 'package:flutter/material.dart';

const _radius = Radius.circular(12);

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

  static Widget decorateItem({
    required BuildContext context,
    required Widget child,
    required bool isFirst,
    required bool isLast,
  }) {
    final borderSide = BorderSide(
      color: Theme.of(context).colorScheme.outlineVariant,
      width: 1,
    );

    final borderRadius = BorderRadius.vertical(
      top: isFirst ? _radius : Radius.zero,
      bottom: isLast ? _radius : Radius.zero,
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border(
          top: isFirst ? borderSide : BorderSide.none,
          bottom: borderSide,
          left: borderSide,
          right: borderSide,
        ),
        borderRadius: borderRadius,
      ),
      child: Material(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return decorateItem(
          context: context,
          child: itemBuilder(context, index),
          isFirst: index == 0,
          isLast: index == itemCount - 1,
        );
      },
    );
  }
}
