import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';

/// A full-bleed, borderless search row sized to align with the list rows it
/// sits above.
class SearchField extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  const SearchField({
    super.key,
    this.controller,
    this.onChanged,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: TextField(
        controller: controller,
        autofocus: autofocus,
        style: mediumStyle,
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle: mediumStyle.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
