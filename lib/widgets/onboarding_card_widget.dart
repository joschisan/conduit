import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';

class OnboardingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionText;
  final VoidCallback? onAction;

  const OnboardingCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: borderRadiusLarge,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: largeIconSize,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(title, style: largeStyle),
                ],
              ),
              const SizedBox(height: 16),
              Text(description, textAlign: TextAlign.center, style: smallStyle),
            ],
          ),
        ),
        if (onAction != null)
          Center(
            child: TextButton(
              onPressed: onAction,
              child: Text(
                actionText ?? '',
                style: mediumStyle.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
