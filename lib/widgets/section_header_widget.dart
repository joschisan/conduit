import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';

/// A list section header: a [title] on the left with an optional trailing
/// [action] link on the right (e.g. "Federations … Join"). The action aligns to
/// the section margin so it sits above the trailing edge of the rows below.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: mediumStyle),
        if (action case final action?)
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(vertical: 4),
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
            onPressed: onAction,
            child: Text(action, style: mediumStyle),
          ),
      ],
    );
  }
}
