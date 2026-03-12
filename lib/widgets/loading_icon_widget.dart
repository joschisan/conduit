import 'package:flutter/material.dart';

class LoadingIcon extends StatelessWidget {
  final Icon icon;

  const LoadingIcon({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        icon,
        const Positioned(
          top: -8,
          left: -8,
          right: -8,
          bottom: -8,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ],
    );
  }
}
