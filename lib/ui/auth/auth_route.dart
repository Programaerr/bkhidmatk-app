import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ألوان شريطي النظام في بقية شاشات التطبيق.
SystemUiOverlayStyle appSystemBars({required bool night}) => SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: night ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    );

/// انتقال الصفحة المعتاد نفسه، لكنه أسرع منه بأكثر من الضعف.
class QuickRoute extends MaterialPageRoute<void> {
  QuickRoute({required super.builder});

  static const _duration = Duration(milliseconds: 200);

  @override
  Duration get transitionDuration => _duration;

  @override
  Duration get reverseTransitionDuration => _duration;
}

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
