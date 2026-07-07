import 'package:flutter/material.dart';

/// Scaffold body wrapper that keeps a fixed column layout while the content
/// fits the viewport and becomes scrollable only once it overflows, e.g. at
/// large accessibility text scales. Flex children ([Spacer]/[Expanded]) keep
/// working while the content fits and collapse once it overflows.
///
/// The safe area sits inside the sliver so the viewport reaches the screen
/// edge and overflowing content scrolls under the home indicator instead of
/// being clipped at the inset.
class ScrollableBody extends StatelessWidget {
  final Widget child;

  const ScrollableBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: SafeArea(child: child),
        ),
      ],
    );
  }
}
