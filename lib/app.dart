import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'state/app_state.dart';
import 'ui/admin/admin_shell.dart';
import 'ui/auth/welcome_screen.dart';
import 'ui/customer/customer_shell.dart';
import 'ui/worker/worker_shell.dart';

class JaikApp extends StatelessWidget {
  const JaikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) => MaterialApp(
        title: 'جايك',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: state.themeMode,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: .9,
          maxScaleFactor: 1.3,
          child: Directionality(textDirection: TextDirection.rtl, child: child!),
        ),
        home: const _RootGate(),
      ),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.booting) return const SplashScreen();
    if (state.user == null) return const WelcomeScreen();
    if (state.isAdmin) return const AdminShell();
    // الموظف بالتوضيف يرى فقط ما تسمح به الإدارة.
    if (state.isWorker) return const WorkerShell();
    return const CustomerShell();
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.ink,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BrandLogoBig(),
            SizedBox(height: 22),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.gold),
            ),
          ],
        ),
      ),
    );
  }
}

class BrandLogoBig extends StatelessWidget {
  const BrandLogoBig({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Image.asset('assets/images/logo.jpg', width: 104, height: 104, fit: BoxFit.cover),
        ),
        const SizedBox(height: 16),
        const Text(
          'جايك',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: AppColors.gold,
          ),
        ),
      ],
    );
  }
}
