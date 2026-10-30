import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bkhidmatk/core/theme.dart';
import 'package:bkhidmatk/data/models.dart';
import 'package:bkhidmatk/state/app_state.dart';
import 'package:bkhidmatk/ui/admin/admin_shell.dart';
import 'package:bkhidmatk/ui/auth/login_screen.dart';
import 'package:bkhidmatk/ui/auth/register_screen.dart';
import 'package:bkhidmatk/ui/auth/welcome_screen.dart';
import 'package:bkhidmatk/ui/customer/customer_shell.dart';

import 'fake_repository.dart';

/// أحجام هواتف حقيقية صغيرة حتى نتأكد أن لا حقل يخرج خارج الشاشة.
const _sizes = <(double, double, double)>[
  (320, 568, 1.3), // أصغر هاتف شائع + أقصى تكبير خط
  (360, 640, 1.0), // most common android
  (412, 915, 1.0), // large phone
];

AppUser _customer() => AppUser(
      id: 1,
      name: 'أحمد سعد',
      phone: '07701234567',
      passwordHash: 'x',
      role: 'customer',
      city: 'بغداد',
      createdAt: DateTime(2026),
      points: 100,
    );

AppUser _admin() => AppUser(
      id: 2,
      name: 'مدير بخدمتك',
      phone: '07700000000',
      passwordHash: 'x',
      role: 'admin',
      createdAt: DateTime(2026),
    );

Future<void> _pumpAt(
  WidgetTester tester, {
  required Widget Function() screen,
  required double width,
  required double height,
  required double textScale,
  AppUser? user,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final state = AppState(
      repository: FakeRepo(customer: user ?? _customer()));
  if (user != null) state.user = user;

  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ar'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        ),
        home: screen(),
      ),
    ),
  );
  // دفع الإطارات حتى تكتمل طلبات المستقبل
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// يجمع كل الاستثناءات المتراكمة (takeException يأخذ واحداً فقط في كل استدعاء).
List<Object> _drainExceptions(WidgetTester tester) {
  final all = <Object>[];
  Object? e;
  while ((e = tester.takeException()) != null) {
    all.add(e!);
  }
  return all;
}

void _expectNoOverflow(WidgetTester tester, String where) {
  final errors = _drainExceptions(tester);
  expect(errors, isEmpty, reason: 'فيض في: $where → ${errors.join('\n')}');
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final (w, h, scale) in _sizes) {
    final label = '${w.toInt()}x${h.toInt()} @${scale}x';

    testWidgets('الشاشات الأولى بدون فيض [$label]', (tester) async {
      await _pumpAt(tester,
          screen: () => const WelcomeScreen(),
          width: w,
          height: h,
          textScale: scale);
      _expectNoOverflow(tester, 'الترحيب $label');

      await _pumpAt(tester,
          screen: () => const LoginScreen(),
          width: w,
          height: h,
          textScale: scale);
      _expectNoOverflow(tester, 'الدخول $label');

      await _pumpAt(tester,
          screen: () => const RegisterScreen(),
          width: w,
          height: h,
          textScale: scale);
      _expectNoOverflow(tester, 'التسجيل $label');
    });

    testWidgets('تبويبات الزبون كاملة بدون فيض [$label]', (tester) async {
      await _pumpAt(tester,
          screen: () => const CustomerShell(),
          width: w,
          height: h,
          textScale: scale,
          user: _customer());
      _expectNoOverflow(tester, 'غلاف الزبون $label');
    });

    testWidgets('تبويبات المدير كاملة بدون فيض [$label]', (tester) async {
      await _pumpAt(tester,
          screen: () => const AdminShell(),
          width: w,
          height: h,
          textScale: scale,
          user: _admin());
      _expectNoOverflow(tester, 'غلاف المدير $label');
    });
  }
}
