import 'package:conduit/bridge_generated.dart/account.dart';

extension AccountName on Account {
  String get displayName => switch (this) {
    Account.primary => 'Primary',
    Account.secondary => 'Secondary',
    Account.tertiary => 'Tertiary',
    Account.quaternary => 'Quaternary',
    Account.quinary => 'Quinary',
  };
}
