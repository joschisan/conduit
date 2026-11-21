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

/// One of a mint's accounts as the picker sees it: the client to hand back
/// when it is chosen, and the live balance to show while choosing.
typedef AccountOption = ({ConduitClient client, ValueListenable<int?> balance});

/// Picks which of a mint's five accounts the pager sits on.
///
/// The pager only carries the accounts worth carrying — primary, plus
/// whichever others hold money or have been asked for — so this is the one
/// place all five are listed. Choosing an empty one is how it gets a page:
/// there is nothing to create, only a balance to start showing.
class SelectAccountDrawer extends StatelessWidget {
  /// Every account of the mint in view, in the order the pager would swipe
  /// them.
  final List<AccountOption> accounts;

  final void Function(ConduitClient) onSelect;

  const SelectAccountDrawer({
    super.key,
    required this.accounts,
    required this.onSelect,
  });

  /// [display] is the unit the balances read in — fiat, or sats — carried in
  /// because the sheet is its own route, outside the home screen's subtree.
  /// Hidden balances read as sats: the sheet is opened to see them.
  static Future<void> show(
    BuildContext context, {
    required List<AccountOption> accounts,
    required void Function(ConduitClient) onSelect,
    required BalanceDisplay display,
  }) {
    return DrawerUtils.show(
      context: context,
      child: AmountDisplay(
        display: display,
        child: SelectAccountDrawer(accounts: accounts, onSelect: onSelect),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DrawerShell(
      children: [
        BorderedList.column(
          children: [for (final option in accounts) _row(option)],
        ),
      ],
    );
  }

  Widget _row(AccountOption option) {
    return ValueListenableBuilder<int?>(
      valueListenable: option.balance,
      builder: (context, sats, _) {
        return SettingsCard(
          // The same chip the home row and the page list carry, so an account
          // reads as an account wherever it is listed.
          icon: PhosphorIconsRegular.wallet,
          title: option.client.account().displayName,
          // Null until the first value lands, which leaves the row single-line
          // rather than claiming a balance of zero it hasn't read yet. Reads
          // in the unit the home screen shows amounts in, fiat or sats.
          subtitle:
              sats == null
                  ? null
                  : formatDisplayedSats(
                    AmountDisplay.of(context),
                    option.client,
                    sats,
                  ),
          // Every row picks, including the account already in view — landing
          // back where you started is a fair answer to opening the list.
          onTap: () {
            Navigator.of(context).pop();
            onSelect(option.client);
          },
        );
      },
    );
  }
}
