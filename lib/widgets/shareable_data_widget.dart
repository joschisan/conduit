import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:conduit/utils/styles.dart';

class ShareableData extends StatelessWidget {
  final String data;

  const ShareableData({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).colorScheme.outlineVariant;

    return GestureDetector(
      onTap: () {
        SharePlus.instance.share(ShareParams(text: data));
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: borderRadiusLarge,
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: ShaderMask(
                    shaderCallback:
                        (bounds) => LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.7, 1.0],
                        ).createShader(bounds),
                    blendMode: BlendMode.dstIn,
                    child: Text(
                      data,
                      maxLines: 1,
                      softWrap: false,
                      style: smallStyle.copyWith(
                        fontFamily: 'monospace',
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              Container(width: 1, color: borderColor),
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 12),
                child: Icon(
                  PhosphorIconsRegular.copy,
                  size: smallIconSize,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
