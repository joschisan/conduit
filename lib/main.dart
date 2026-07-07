import 'dart:io';
import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:conduit/bridge_generated.dart/frb_generated.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/screens/landing_screen.dart';
import 'package:conduit/screens/base_screen.dart';
import 'package:conduit/screens/federation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // iOS uses static linking, Android uses dynamic library
  if (Platform.isIOS) {
    await RustLib.init(
      externalLibrary: ExternalLibrary.process(iKnowHowToUseIt: true),
    );
  } else {
    await RustLib.init();
  }

  final dir = await getApplicationDocumentsDirectory();

  final db = await openDatabase(dbPath: dir.path);

  final clientFactory = await ConduitClientFactory.tryLoad(db: db);

  if (clientFactory == null) {
    runApp(ConduitApp(home: LandingScreen(db: db)));
    return;
  }

  // Open the persisted federation before the first frame so the wallet itself
  // is the first thing shown (the OS splash stays up until it's ready). Only
  // onboarding (no federations) and a still-recovering federation fall back to
  // BaseScreen, which hosts the scanner and the recovery hand-off.
  final client = await clientFactory.loadCurrent();

  // Open the wallet directly unless a recovery is running that holds a module
  // back — when every module stays usable mid-recovery, the wallet opens now
  // and surfaces progress on its own, rather than blocking on BaseScreen.
  if (client != null &&
      (!client.hasPendingRecoveries() || client.allModulesUsable())) {
    runApp(
      ConduitApp(
        home: FederationScreen(client: client, clientFactory: clientFactory),
      ),
    );
  } else {
    await client?.shutdown();
    runApp(ConduitApp(home: BaseScreen(clientFactory: clientFactory)));
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
        navigatorObservers: [routeObserver],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
          fontFamily: GoogleFonts.inter().fontFamily,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            titleTextStyle: mediumStyle,
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          fontFamily: GoogleFonts.inter().fontFamily,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            titleTextStyle: mediumStyle,
          ),
        ),
        themeMode: ThemeMode.dark,
        home: home,
      ),
    );
  }
}
