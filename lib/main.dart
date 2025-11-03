import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:conduit/bridge_generated.dart/frb_generated.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/screens/wallet_choice_screen.dart';
import 'package:conduit/screens/settings_screen.dart';
import 'package:conduit/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await RustLib.init();

  final dir = await getApplicationDocumentsDirectory();

  final db = await openDatabase(dbPath: dir.path);

  final clientFactory = await ConduitClientFactory.tryLoad(db: db);

  if (clientFactory != null) {
    final client = await clientFactory.loadSelected();

    if (client != null) {
      runApp(
        ConduitApp(
          home: HomeScreen(client: client, clientFactory: clientFactory),
        ),
      );
    } else {
      runApp(ConduitApp(home: SettingsScreen(clientFactory: clientFactory)));
    }
  } else {
    runApp(ConduitApp(home: WalletChoiceScreen(db: db)));
  }
}

class ConduitApp extends StatelessWidget {
  final Widget home;

  const ConduitApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return OverlaySupport.global(
      child: MaterialApp(
        title: 'Conduit',
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
