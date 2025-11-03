import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:conduit/bridge_generated.dart/frb_generated.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/screens/wallet_choice_screen.dart';
import 'package:conduit/screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await RustLib.init();

  final dir = await getApplicationDocumentsDirectory();

  final db = await openDatabase(dbPath: dir.path);

  final initializedDb = await InitializedDatabase.tryLoad(db: db);

  if (initializedDb != null) {
    runApp(EcashApp(home: SettingsScreen(initializedDb: initializedDb)));
  } else {
    runApp(EcashApp(home: WalletChoiceScreen(db: db)));
  }
}

class EcashApp extends StatelessWidget {
  final Widget home;

  const EcashApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return OverlaySupport.global(
      child: MaterialApp(
        title: 'Ecash App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.dark,
        home: home,
      ),
    );
  }
}
