import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:conduit/bridge_generated.dart/frb_generated.dart';
import 'package:conduit/bridge_generated.dart/lib.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/screens/landing_screen.dart';
import 'package:conduit/screens/base_screen.dart';

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

  if (clientFactory != null) {
    final initialClient = await clientFactory.loadSelected();

    runApp(
      ConduitApp(
        home: BaseScreen(
          clientFactory: clientFactory,
          initialClient: initialClient,
        ),
      ),
    );
  } else {
    runApp(ConduitApp(home: LandingScreen(db: db)));
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
