import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'app.dart';
import 'data/supabase_services.dart';
import 'state/app_state.dart';
import 'ui/auth/supabase_setup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  final cloudServices = await SupabaseServices.initializeIfConfigured();
  if (kIsWeb && cloudServices == null) {
    runApp(const SupabaseSetupApp());
    return;
  }

  final state = AppState(cloudServices: cloudServices);
  await state.boot();

  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const JaikApp(),
    ),
  );
}
