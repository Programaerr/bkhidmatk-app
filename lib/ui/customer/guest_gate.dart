import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/language.dart';
import '../../state/app_state.dart';
import '../auth/login_screen.dart';
import '../widgets/quick_route.dart';
import '../widgets/ui.dart';

/// الضيف يتصفح الرئيسية والأقسام وبطاقات الحرفيين فقط. تفاصيل الحرفي والأعمال والرسائل والحجز
/// والحساب تطلب منه تسجيل الدخول أولاً. ترجع true إن كان للمستخدم حساب.
bool hasAccount(BuildContext context) {
  if (context.read<AppState>().user != null) return true;
  unawaited(_askToLogIn(context));
  return false;
}

// شريط القوائم قد يبلّغ عن اللمسة مرتين، فلا تُفتح الرسالة مرتين.
bool _asking = false;

Future<void> _askToLogIn(BuildContext context) async {
  if (_asking) return;
  _asking = true;
  final bool logIn;
  try {
    logIn = await _ask(context);
  } finally {
    _asking = false;
  }
  if (!logIn || !context.mounted) return;
  // التطبيق يرجع إلى الشاشة الأولى، وصفحة الدخول فوقها، وفيها إنشاء حساب جديد.
  final navigator = Navigator.of(context, rootNavigator: true);
  context.read<AppState>().leaveGuest();
  unawaited(navigator.push(QuickRoute(builder: (_) => const LoginScreen())));
}

Future<bool> _ask(BuildContext context) {
  return confirmAction(
    context,
    title: tr('سجّل الدخول أولاً', 'Log in first'),
    message: tr(
      'أنت تتصفح كضيف. سجّل الدخول إلى حسابك أو أنشئ حساباً جديداً لتستخدم هذا.',
      'You are browsing as a guest. Log in or create a new account to use this.',
    ),
    confirmLabel: tr('تسجيل الدخول', 'Log in'),
  );
}
