import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';

class WarningCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const WarningCard({
    required this.icon,
    required this.text,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: borderRadiusLarge,
          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.amber[700], size: smallIconSize),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: mediumStyle.copyWith(color: Colors.amber[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
