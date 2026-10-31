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

  group('مخرج المشهد', () {
    void run(VanDirector director, double seconds) {
      for (var i = 0; i < seconds * 60; i++) {
        director.advance(1 / 60);
      }
    }

    test('يقول جايك بطريق مرة واحدة عند الفتح ولا يكررها', () {
      final director = VanDirector();
      expect(director.window, 0);
      expect(director.bubble, 0);

      run(director, 4);
      expect(director.window, 1);
      expect(director.bubble, 1);
      expect(director.line, VanLine.greeting);

      run(director, 4);
      expect(director.window, 0);
      expect(director.bubble, 0);

      run(director, 30);
      expect(director.window, 0);
      expect(director.bubble, 0);
      expect(director.speed, closeTo(1, .001));
    });

    test('الضغط على السيارة يقول يلا جايك بطريق ويسرع ثم يهدأ', () {
      final director = VanDirector();
      run(director, 10);
      final before = director.travel;
      run(director, 1);
      final normalDistance = director.travel - before;

      director.tap();
      run(director, 2);
      expect(director.line, VanLine.hurry);
      expect(director.window, 1);
      expect(director.bubble, 1);
      expect(director.speed, greaterThan(3));
      expect(director.effort, greaterThan(.8));

      final fastStart = director.travel;
      run(director, 1);
      expect(director.travel - fastStart, greaterThan(normalDistance * 3));

      run(director, 6);
      expect(director.window, 0);
      expect(director.bubble, 0);
      expect(director.speed, closeTo(1, .01));
      expect(director.effort, closeTo(0, .01));
    });

    test('الضغط أثناء الترحيب يبدّل الكلام مباشرة دون قفز الجامة', () {
      final director = VanDirector();
      run(director, 4);
      director.tap();
      director.advance(1 / 60);

      expect(director.line, VanLine.hurry);
      expect(director.window, 1);
      expect(director.bubble, 1);
    });

    test('المسافة لا تقفز إذا توقفت الإطارات ثم عادت', () {
      final director = VanDirector();
      director.advance(3600);
      expect(director.travel, lessThan(.2));
    });
  });

  testWidgets('الضغط على السيارة يسرعها، والضغط خارجها لا يغيّر شيئاً', (tester) async {
    await _pump(tester);
    VanDirector director() => (tester
            .widget<CustomPaint>(
              find.descendant(of: find.byType(TruckScene), matching: find.byType(CustomPaint)),
            )
            .painter! as TruckScenePainter)
        .director;

    final scene = tester.getRect(find.byType(TruckScene));
    await tester.tapAt(scene.topLeft + const Offset(4, 4));
    await tester.pump();
    expect(director().line, VanLine.greeting);

    await tester.tap(find.bySemanticsLabel('السيارة، اضغط عليها لتسرع'));
    await tester.pump();
    expect(director().line, VanLine.hurry);
  });

  test('قارئ مسارات SVG يفهم الصيغة المختصرة والأقواس', () {
    expect(parseSvgPath('M0,0h10v10h-10Z').getBounds(), const Rect.fromLTRB(0, 0, 10, 10));
    expect(parseSvgPath('M1-2l.5.5-1.5 1.5Z').getBounds(), const Rect.fromLTRB(0, -2, 1.5, 0));

    final circle = parseSvgPath('M0,5A5,5,0,1,0,10,5A5,5,0,1,0,0,5Z').getBounds();
    expect(circle.width, closeTo(10, .01));
    expect(circle.height, closeTo(10, .01));
  });
}
