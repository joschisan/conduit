import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/widgets/async_button_widget.dart';

class TextEntryBody extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Future<void> Function() onConfirm;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;

  const TextEntryBody({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onConfirm,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: focusNode.requestFocus,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: EditableText(
                    controller: controller,
                    focusNode: focusNode,
                    style: largeStyle,
                    cursorColor: Theme.of(context).colorScheme.primary,
                    textAlign: TextAlign.center,
                    textCapitalization: textCapitalization,
                    keyboardType: keyboardType,
                    keyboardAppearance: Brightness.dark,
                    autocorrect: false,
                    enableSuggestions: false,
                    backgroundCursorColor: Colors.transparent,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AsyncButton(text: 'Confirm', onPressed: onConfirm),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
