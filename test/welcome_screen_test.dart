import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:jaik/core/theme.dart';
import 'package:jaik/state/app_state.dart';
import 'package:jaik/ui/auth/login_screen.dart';
import 'package:jaik/ui/auth/register_screen.dart';
import 'package:jaik/ui/auth/truck_scene.dart';
import 'package:jaik/ui/auth/welcome_screen.dart';

import 'fake_repository.dart';

class _Repo extends FakeRepo {
  _Repo({required this.registered});

  final bool registered;
  final asked = <String>[];

  @override
  Future<bool> phoneExists(String phone) async {
    asked.add(phone);
    return registered;
  }
}

Future<_Repo> _pump(
  WidgetTester tester, {
  bool registered = false,
  bool disableAnimations = false,
}) async {
  final repo = _Repo(registered: registered);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: AppState(repository: repo),
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ar'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
          child: Directionality(textDirection: TextDirection.rtl, child: child!),
        ),
        home: const WelcomeScreen(),
      ),
    ),
  );
  await tester.pump();
  return repo;
}

Future<void> _submit(WidgetTester tester, String phone) async {
  await tester.enterText(find.byType(TextField), phone);
  await tester.tap(find.text('تسجيل الدخول'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('الرقم غير العراقي لا ينتقل لشاشة أخرى ويعرض خطأ', (tester) async {
    final repo = await _pump(tester);
    await _submit(tester, '1234567890');

    expect(find.text('أدخل رقم موبايل عراقي صحيح يبدأ بـ 07'), findsOneWidget);
    expect(repo.asked, isEmpty);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(RegisterScreen), findsNothing);
  });

  testWidgets('الرقم المسجل يكمل بكلمة المرور ولا يدخل بدونها', (tester) async {
    final repo = await _pump(tester, registered: true);
    await _submit(tester, '7701234567');

    expect(repo.asked, ['07701234567']);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('07701234567'), findsOneWidget);
    final state = tester.element(find.byType(LoginScreen)).read<AppState>();
    expect(state.user, isNull);
  });

  testWidgets('الرقم الجديد يكمل بإنشاء حساب', (tester) async {
    final repo = await _pump(tester);
    await _submit(tester, '07711112222');

    expect(repo.asked, ['07711112222']);
    expect(
      find.descendant(of: find.byType(RegisterScreen), matching: find.text('07711112222')),
      findsOneWidget,
    );
  });

  testWidgets('الأرقام العربية و+964 تتحول إلى رقم موبايل فقط', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField), '+٩٦٤ ٧٧٠ ١٢٣ ٤٥٦٧ ٩٩');

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '7701234567');
  });

  testWidgets('المشهد يتحرك في الوضع العادي', (tester) async {
    await _pump(tester);
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('المشهد يثبت إذا عطّل المستخدم الحركات من الجهاز', (tester) async {
    await _pump(tester, disableAnimations: true);
    expect(tester.hasRunningAnimations, isFalse);
  });

  test('السائق: النافذة مغلقة في البداية ثم يرفع إبهامه ثم يعود', () {
    final start = DriverPose.at(0);
    expect(start.window, 0);
    expect(start.hand, 0);

    final thumbsUp = DriverPose.at(4);
    expect(thumbsUp.window, 1);
    expect(thumbsUp.hand, 1);

    final end = DriverPose.at(DriverPose.loop - .1);
    expect(end.window, 0);
    expect(end.hand, 0);
  });

  test('قارئ مسارات SVG يفهم الصيغة المختصرة والأقواس', () {
    expect(parseSvgPath('M0,0h10v10h-10Z').getBounds(), const Rect.fromLTRB(0, 0, 10, 10));
    expect(parseSvgPath('M1-2l.5.5-1.5 1.5Z').getBounds(), const Rect.fromLTRB(0, -2, 1.5, 0));

    final circle = parseSvgPath('M0,5A5,5,0,1,0,10,5A5,5,0,1,0,0,5Z').getBounds();
    expect(circle.width, closeTo(10, .01));
    expect(circle.height, closeTo(10, .01));
  });
}
