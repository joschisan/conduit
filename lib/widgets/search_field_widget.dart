import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';

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
    final inputBorder = OutlineInputBorder(
      borderRadius: borderRadiusLarge,
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        style: mediumStyle,
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle: mediumStyle,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Icon(
              Icons.search,
              size: mediumIconSize,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          border: inputBorder,
          enabledBorder: inputBorder,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
