import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jaik/core/theme.dart';
import 'package:jaik/state/app_state.dart';
import 'package:jaik/ui/auth/account_type_screen.dart';
import 'package:jaik/ui/auth/craftsman_screen.dart';
import 'package:jaik/ui/auth/login_screen.dart';
import 'package:jaik/ui/auth/push_key.dart';
import 'package:jaik/ui/auth/register_screen.dart';
import 'package:jaik/ui/auth/thinking_scene.dart';
import 'package:jaik/ui/auth/truck_scene.dart';

import 'fake_repository.dart';

Future<void> _pumpApp(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(392, 825),
  ThemeData? theme,
  bool disableAnimations = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: AppState(repository: FakeRepo()),
      child: MaterialApp(
        theme: theme ?? AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
          child: Directionality(textDirection: TextDirection.rtl, child: child!),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
                child: const Text('الصفحة السابقة'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('الصفحة السابقة'));
  await _settle(tester);
}

/// المشهد يتحرك دائماً، فلا تكتمل pumpAndSettle.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(392, 825),
  ThemeData? theme,
  bool disableAnimations = false,
}) =>
    _pumpApp(
      tester,
      const AccountTypeScreen(),
      size: size,
      theme: theme,
      disableAnimations: disableAnimations,
    );

Finder _key(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(PushKey));

Finder get _backKey => find.descendant(of: find.byType(PushKeyBack), matching: find.byType(PushKey));

void main() {
  testWidgets('رابط إنشاء حساب جديد في صفحة الدخول يفتح هذه الصفحة', (tester) async {
    await _pumpApp(tester, const LoginScreen());
    await tester.ensureVisible(find.text('إنشاء حساب جديد'));
    await tester.pump();
    await tester.tap(find.text('إنشاء حساب جديد'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final page = tester.element(find.byType(AccountTypeScreen));
    expect(ModalRoute.of(page)!.animation!.value, 1);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    await tester.tap(_backKey);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 201));
    await tester.pump();
    expect(find.byType(AccountTypeScreen), findsNothing);
    expect(find.text('إنشاء حساب جديد'), findsOneWidget);
  });

  testWidgets('زبون على اليمين وحرفي على اليسار، بنفس المقاس وفي وسط الشاشة', (tester) async {
    await _pump(tester);
    expect(find.byType(PushKeyButton), findsNWidgets(2));
    final customer = tester.getRect(_key('زبون'));
    final craftsman = tester.getRect(_key('حرفي'));
    expect(customer.left, greaterThan(craftsman.right));
    expect(customer.top, craftsman.top);
    expect(customer.size, craftsman.size);
    expect((customer.right + craftsman.left) / 2, closeTo(392 / 2, .5));
    expect(tester.widget<PushKey>(_key('زبون')).yellow, isFalse);
    expect(tester.widget<PushKey>(_key('حرفي')).yellow, isFalse);
  });

  testWidgets('الزران بخط أزرار الشاشة الأولى ولونها', (tester) async {
    await _pump(tester);
    final style = tester.widget<Text>(find.text('زبون')).style!;
    expect(style.fontFamily, 'Cairo');
    expect(style.fontWeight, FontWeight.w800);
    expect(style.color, const Color(0xFF263238));
  });

  testWidgets('زر زبون يفتح إنشاء حساب بسرعة', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('زبون'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final page = tester.element(find.byType(RegisterScreen));
    expect(ModalRoute.of(page)!.animation!.value, 1);
  });

  testWidgets('زر حرفي يفتح صفحة الحرفي بسرعة', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('حرفي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final page = tester.element(find.byType(CraftsmanScreen));
    expect(ModalRoute.of(page)!.animation!.value, 1);
  });

  testWidgets('زر الرجوع بالسهم نفسه في الزاوية، بلا اسم يظهر عند الوقوف عليه', (tester) async {
    await _pump(tester);
    expect(find.descendant(of: _backKey, matching: find.byIcon(Icons.arrow_back)), findsOneWidget);
    expect(find.byType(Tooltip), findsNothing);
    expect(find.byType(BackButton), findsNothing);
    // العرض 392 يجعل مقياس الأزرار 392 / 391.
    expect(tester.getRect(_backKey).right, closeTo(392 - 19.9 * 392 / 391, .5));

    await tester.tap(_backKey);
    await _settle(tester);
    expect(find.text('الصفحة السابقة'), findsOneWidget);
  });

  testWidgets('زر الرجوع يبقى تحت شريط الحالة', (tester) async {
    tester.view
      ..padding = const FakeViewPadding(top: 40)
      ..viewPadding = const FakeViewPadding(top: 40);
    await _pump(tester);
    expect(tester.getRect(_backKey).top, greaterThanOrEqualTo(40));
  });

  for (final size in const [Size(392, 825), Size(360, 780), Size(412, 915), Size(320, 568)]) {
    testWidgets('الفراغ فوق الزرين مثل الفراغ تحتهما في هاتف $size', (tester) async {
      await _pump(tester, size: size);
      final hill = tester.getRect(find.byType(ThinkingScene)).bottom;
      final key = tester.getRect(_key('زبون'));
      // الفراغ السفلي يمتد إلى أيقونات شريط التنقل، وهي تحت حافة التطبيق بنحو 14.
      expect(key.top - hill, closeTo(size.height + 14 - key.bottom, 1));
    });
  }

  testWidgets('الجهة العليا بارتفاع الشاشة الأولى ولونها', (tester) async {
    await _pump(tester);
    expect(tester.getRect(find.byType(ThinkingScene)).height, closeTo(825 * 414.3 / 715, .5));
    expect(TruckSceneMetrics.hillColor, const Color(0xFFE2E255));
  });

  testWidgets('في الليل تصير الأرض سوداء والأزرار بألوان الليل', (tester) async {
    await _pump(tester, theme: AppTheme.dark());
    final scaffold = tester.widget<Scaffold>(
      find.descendant(of: find.byType(AccountTypeScreen), matching: find.byType(Scaffold)),
    );
    expect(scaffold.backgroundColor, Colors.black);
    expect(tester.widget<PushKey>(_key('زبون')).night.value, 1);
    expect(tester.widget<PushKey>(_backKey).night.value, 1);
    expect(tester.widget<Text>(find.text('حرفي')).style!.color, const Color(0xFFF4F4EE));
  });

  testWidgets('الشاشة القصيرة تعرض الزرين بالسحب', (tester) async {
    await _pump(tester, size: const Size(800, 300));
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
    await tester.pump();
    expect(tester.getRect(_key('زبون')).bottom, lessThan(300));
  });

  testWidgets('الشخصية تتحرك في الوضع العادي', (tester) async {
    await _pump(tester);
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('الشخصية تثبت إذا عطّل المستخدم الحركات من الجهاز', (tester) async {
    await _pump(tester, disableAnimations: true);
    expect(tester.hasRunningAnimations, isFalse);
  });

  group('حركة الشخصية', () {
    test('تفكر أولاً، ثم تأتيها الفكرة فيضيء المصباح ويرجع', () {
      expect(const ThinkingPose(3).idea, 0);
      expect(const ThinkingPose(3).light, 0);
      expect(const ThinkingPose(7).idea, 1);
      expect(const ThinkingPose(7).light, 1);
      expect(const ThinkingPose(8.8).idea, 0);
      expect(const ThinkingPose(8.8).light, 0);
    });

    test('المصباح يرتجف قبل أن يضيء', () {
      expect(const ThinkingPose(5.76).light, closeTo(.35, .01));
      expect(const ThinkingPose(5.95).light, 0);
      expect(const ThinkingPose(6.08).light, closeTo(.6, .01));
      expect(const ThinkingPose(6.35).light, 0);
    });

    test('ترمش ثم تفتح عينيها', () {
      expect(const ThinkingPose(1).blink, 0);
      expect(const ThinkingPose(1.68).blink, 1);
      expect(const ThinkingPose(2).blink, 0);
    });

    test('تنقر بأصابعها فترة من الدورة فقط', () {
      expect(const ThinkingPose(1).handTap, 0);
      expect(const ThinkingPose(3.2).handTap.abs(), greaterThan(0));
      expect(const ThinkingPose(5).handTap, 0);
    });

    test('لا تقفز أي حركة عند بداية الدورة التالية', () {
      const before = ThinkingPose(ThinkingPose.cycle - .001);
      const after = ThinkingPose(ThinkingPose.cycle + .001);
      expect(after.gearTime - before.gearTime, closeTo(.002, .001));
      expect(after.headTilt, closeTo(before.headTilt, .001));
      expect(after.bodyLift, closeTo(before.bodyLift, .01));
      expect(after.light, closeTo(before.light, .001));
      expect(after.eyes.dy, closeTo(before.eyes.dy, .01));
    });

    test('التروس تتسارع عند الفكرة ثم ترجع إلى سرعتها', () {
      double speed(double time) =>
          (ThinkingPose(time + .01).gearTime - ThinkingPose(time).gearTime) / .01;
      expect(speed(3), closeTo(1, .001));
      expect(speed(7), greaterThan(1.5));
      expect(speed(8.5), closeTo(1, .001));
    });
  });
}
