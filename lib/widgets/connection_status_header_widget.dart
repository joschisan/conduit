import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
import 'package:conduit/widgets/icon_chip_widget.dart';

/// Overall federation reachability shown above the guardian list, as a row that
/// mirrors the guardian rows: a connectivity icon-chip badge with the federation
/// name as the header and an online/offline status beneath.
///
/// The federation is reachable once at least [_threshold] guardians are online,
/// using fedimint's consensus threshold `n - ⌊(n-1)/3⌋` (e.g. 4→3, 7→5). The
/// badge is green while reachable and turns amber when too few are connected.
class ConnectionStatusHeader extends StatelessWidget {
  final String name;
  final int online;
  final int total;

  const ConnectionStatusHeader({
    super.key,
    required this.name,
    required this.online,
    required this.total,
  });

  int get _threshold => total - ((total - 1) ~/ 3);

  @override
  Widget build(BuildContext context) {
    final operational = online >= _threshold;
    final color = operational ? Colors.green : Colors.amber;

    return ListTile(
      contentPadding: listTilePadding,
      leading: IconChip(icon: PhosphorIconsRegular.broadcast, color: color),
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name, style: mediumStyle),
          Text(
            operational ? 'Online' : 'Offline',
            style: smallStyle.copyWith(
              color: operational ? Colors.green : null,
            ),
          ),
        ],
      ),
    );
  }
}
