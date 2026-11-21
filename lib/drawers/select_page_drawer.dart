import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/utils/account_utils.dart';
import 'package:conduit/utils/currency_utils.dart';
import 'package:conduit/utils/drawer_utils.dart';
import 'package:conduit/widgets/amount_visibility.dart';
import 'package:conduit/widgets/bordered_list_widget.dart';
import 'package:conduit/widgets/drawer_shell_widget.dart';
import 'package:conduit/widgets/settings_card_widget.dart';

/// One page of the pager as the list sees it: the client to page to when it
/// is chosen, and the balance to show while choosing — live, since the page
/// it describes keeps updating behind the sheet. The mint name rides on the
/// client itself.
typedef PageOption = ({ConduitClient client, ValueListenable<int?> balance});

/// Lists what the pager carries, so a balance can be jumped to instead of
/// swiped to.
///
/// The same pages in the same order — this is the swipe written out as a
/// list, which is what a wallet holding several mints wants once the page it
/// is after is two or three swipes away. Mint-wide, unlike
/// [SelectAccountDrawer], which stays inside the mint in view and is the only
/// place an account without a page can be reached.
class SelectPageDrawer extends StatelessWidget {
  /// Every page the pager carries, in the order it swipes them.
  final List<PageOption> pages;

  /// The page in view, tinted so the list says where the swipe would start
  /// from. Keyed the same way the caller keys its pages.
  final String selectedKey;

  /// How a page is keyed, so [selectedKey] can be matched against a row
  /// without this drawer knowing what identifies an account.
  final String Function(ConduitClient) keyOf;

  final void Function(ConduitClient) onSelect;

  const SelectPageDrawer({
    super.key,
    required this.pages,
    required this.selectedKey,
    required this.keyOf,
    required this.onSelect,
  });

  /// [display] is the unit the balances read in — fiat, or sats — carried in
  /// because the sheet is its own route, outside the home screen's subtree.
  /// Hidden balances read as sats: the sheet is opened to see them.
  static Future<void> show(
    BuildContext context, {
    required List<PageOption> pages,
    required String selectedKey,
    required String Function(ConduitClient) keyOf,
    required void Function(ConduitClient) onSelect,
    required BalanceDisplay display,
  }) {
    return DrawerUtils.show(
      context: context,
      child: AmountDisplay(
        display: display,
        child: SelectPageDrawer(
          pages: pages,
          selectedKey: selectedKey,
          keyOf: keyOf,
          onSelect: onSelect,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DrawerShell(
      children: [
        // Scrollable: three mints at five accounts each is more rows than a
        // sheet can show, and the list is the whole sheet.
        Flexible(
          child: SingleChildScrollView(
            child: BorderedList.column(
              children: [for (final page in pages) _row(context, page)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, PageOption page) {
    final selected = keyOf(page.client) == selectedKey;

    return ValueListenableBuilder<int?>(
      valueListenable: page.balance,
      builder: (context, sats, _) {
        return SettingsCard(
          icon: PhosphorIconsRegular.wallet,
          iconColor: selected ? Theme.of(context).colorScheme.primary : null,
          // The mint leads, as it does on the row this opens from: across
          // mints it is what tells two pages apart, and the account is the
          // qualifier under it.
          title: page.client.federationName(),
          subtitle: _subtitle(context, page.client, sats),
          // Every row picks, including the page already in view — landing
          // back where you started is a fair answer to opening the list.
          onTap: () {
            Navigator.of(context).pop();
            onSelect(page.client);
          },
        );
      },
    );
  }

  /// Account and balance on one line, the balance in the unit the home
  /// screen shows amounts in. Drops the balance until the first value lands
  /// rather than claiming a zero it hasn't read yet.
  String _subtitle(BuildContext context, ConduitClient client, int? sats) {
    final account = client.account().displayName;

    if (sats == null) return account;

    return '$account · ${formatDisplayedSats(AmountDisplay.of(context), client, sats)}';
  }
}
