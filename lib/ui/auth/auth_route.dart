import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/quick_route.dart';

/// ألوان شريطي النظام في بقية شاشات التطبيق.
SystemUiOverlayStyle appSystemBars({required bool night}) => SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: night ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    );

/// يفتح صفحة من صفحات الدخول بالانتقال السريع وبألوان شريطي النظام.
void openAuthPage(BuildContext context, Widget page, {required bool night}) {
  Navigator.push(
    context,
    QuickRoute(
      builder: (_) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: appSystemBars(night: night),
        child: page,
      ),
    ),
  );
}
