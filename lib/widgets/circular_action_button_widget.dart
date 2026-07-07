import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/utils/async_button_mixin.dart';

class CircularActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Future<void> Function() onTap;

  const CircularActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<CircularActionButton> createState() => _CircularActionButtonState();
}

class _CircularActionButtonState extends State<CircularActionButton>
    with AsyncButtonMixin {
  @override
  Future<void> Function() get onPressed => widget.onTap;

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final loading = buttonState == AsyncButtonState.loading;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Theme.of(context).colorScheme.primary,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            // handlePress supplies the haptic; disabled while loading.
            onTap: loading ? null : handlePress,
            child: SizedBox(
              width: 64,
              height: 64,
              child: Center(
                child:
                    loading
                        ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(onPrimary),
                          ),
                        )
                        : Icon(
                          widget.icon,
                          size: mediumIconSize,
                          color: onPrimary,
                        ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.label,
          style: smallStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
