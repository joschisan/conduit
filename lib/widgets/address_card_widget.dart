import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';

class AddressCard extends StatelessWidget {
  final String address;

  const AddressCard({super.key, required this.address});

  List<String> get _chunks => [
    for (var i = 0; i < address.length; i += 4)
      address.substring(i, i + 4 > address.length ? address.length : i + 4),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: borderRadiusLarge,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.0,
          mainAxisSpacing: 0,
          crossAxisSpacing: 0,
          children:
              _chunks.map((chunk) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    chunk,
                    style: mediumStyle.copyWith(fontFamily: 'monospace'),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }
}
