import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/supabase_services.dart';
import 'state/app_state.dart';
import 'ui/auth/supabase_setup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  if (kIsWeb && !SupabaseServices.isConfigured) {
    runApp(const SupabaseSetupApp());
    return;
  }
  final cloudServices = await SupabaseServices.initializeIfConfigured();
  final state = AppState(cloudServices: cloudServices);
  await state.boot();

  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const JaikApp(),
    ),
  );
}
