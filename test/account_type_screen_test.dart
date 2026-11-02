import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jaik/core/theme.dart';
import 'package:jaik/state/app_state.dart';
import 'package:jaik/ui/auth/account_type_screen.dart';
import 'package:jaik/ui/auth/craftsman_screen.dart';
import 'package:jaik/ui/auth/login_screen.dart';
import 'package:jaik/ui/auth/privacy_screen.dart';
import 'package:jaik/ui/auth/push_key.dart';
import 'package:jaik/ui/auth/register_screen.dart';
import 'package:jaik/ui/auth/thinking_scene.dart';
import 'package:jaik/ui/auth/truck_scene.dart';

import 'fake_repository.dart';
import 'route_frames.dart';

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

const _privacy = 'سياسة و الخصوصية';

ValueListenable<double> _answer(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(of: find.byType(ThinkingScene), matching: find.byType(CustomPaint)),
  );
  return (paint.painter! as ThinkingScenePainter).answer;
}

/// يضغط على الغيمة نفسها في الرسم.
Future<void> _pressCloud(WidgetTester tester) async {
  final scene = tester.getRect(find.byType(ThinkingScene));
  await tester.tapAt(scene.center + Offset(scene.width * .25, -scene.height * .17));
  await tester.pump();
}

void main() {
  testWidgets('رابط إنشاء حساب جديد في صفحة الدخول يفتح هذه الصفحة', (tester) async {
    await _pumpApp(tester, const LoginScreen());
    await tester.ensureVisible(find.text('إنشاء حساب جديد'));
    await tester.pump();
    await tester.tap(find.text('إنشاء حساب جديد'));
    await tester.pump();
    await pumpRouteFrames(tester);
    final page = tester.element(find.byType(AccountTypeScreen));
    expect(ModalRoute.of(page)!.animation!.value, 1);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    await tester.tap(_backKey);
    await tester.pump();
    await pumpRouteFrames(tester);
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
    await pumpRouteFrames(tester);
    final page = tester.element(find.byType(RegisterScreen));
    expect(ModalRoute.of(page)!.animation!.value, 1);
  });

  testWidgets('زر حرفي يفتح صفحة الحرفي بسرعة', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('حرفي'));
    await tester.pump();
    await pumpRouteFrames(tester);
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
    testWidgets('الفراغ فوق الزرين مثل الفراغ تحت الخصوصية في هاتف $size', (tester) async {
      await _pump(tester, size: size);
      final hill = tester.getRect(find.byType(ThinkingScene)).bottom;
      final privacy = tester.getRect(find.text(_privacy));
      // فوق الزر هامش لمس لا يُرى، والفراغ السفلي يمتد إلى أيقونات شريط التنقل، وهي تحت حافة التطبيق بنحو 14.
      final gapAbove = tester.getRect(_key('زبون')).top - 3 - hill;
      expect(gapAbove, closeTo(size.height + 14 - privacy.bottom, 1));
    });
  }

  testWidgets('«سياسة و الخصوصية» تحت الزرين وفي وسطهما، بخط كلامها في الشاشة الأولى', (tester) async {
    await _pump(tester);
    final text = tester.getRect(find.text(_privacy));
    final customer = tester.getRect(_key('زبون'));
    final craftsman = tester.getRect(_key('حرفي'));
    expect(text.top, greaterThan(customer.bottom));
    expect(text.center.dx, closeTo((customer.right + craftsman.left) / 2, .5));
    final style = tester.widget<Text>(find.text(_privacy)).style!;
    expect(style.fontFamily, 'Cairo');
    expect(style.fontWeight, FontWeight.w700);
    expect(style.color, const Color(0xFF383838));
  });

  testWidgets('«سياسة و الخصوصية» زر يفتح صفحتها بسرعة، وزر الرجوع يعيد منها', (tester) async {
    await _pump(tester);
    await tester.tap(find.text(_privacy));
    await tester.pump();
    await pumpRouteFrames(tester);
    final page = tester.element(find.byType(PrivacyScreen));
    expect(ModalRoute.of(page)!.animation!.value, 1);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    await tester.tap(
      find.descendant(of: find.byType(PrivacyScreen), matching: find.byType(PushKey)),
    );
    await tester.pump();
    await pumpRouteFrames(tester);
    await tester.pump();
    expect(find.byType(PrivacyScreen), findsNothing);
    expect(find.text(_privacy), findsOneWidget);
  });

  testWidgets('مساحة لمس «سياسة و الخصوصية» تكفي الإصبع، ولا تأخذ ضغطة الزرين', (tester) async {
    await _pump(tester);
    final button = find.ancestor(of: find.text(_privacy), matching: find.byType(TextButton));
    expect(tester.getRect(button).height, greaterThanOrEqualTo(44));

    final key = tester.getRect(_key('زبون'));
    await tester.tapAt(Offset(key.left + 10, key.bottom - 1));
    await tester.pump();
    await pumpRouteFrames(tester);
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.byType(PrivacyScreen), findsNothing);
  });

  testWidgets('«سياسة و الخصوصية» فاتحة في الليل', (tester) async {
    await _pump(tester, theme: AppTheme.dark());
    expect(tester.widget<Text>(find.text(_privacy)).style!.color, const Color(0xFFF4F4EE));
  });

  group('الضغط على الرسم', () {
    testWidgets('الغيمة تتغير إلى «ها فكرت» ثم ترجع بعد مدة', (tester) async {
      await _pump(tester);
      final answer = _answer(tester);
      expect(answer.value, 0);

      await _pressCloud(tester);
      await tester.pump(const Duration(milliseconds: 450));
      expect(answer.value, 1);

      await tester.pump(const Duration(milliseconds: 2700));
      expect(answer.value, 1);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 450));
      expect(answer.value, 0);
    });

    testWidgets('الضغط مرة ثانية يطيل بقاء الكلام بلا رمشة', (tester) async {
      await _pump(tester);
      final answer = _answer(tester);
      await _pressCloud(tester);
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump(const Duration(seconds: 2));

      await _pressCloud(tester);
      expect(answer.value, 1);
      await tester.pump(const Duration(seconds: 2));
      expect(answer.value, 1);

      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 450));
      expect(answer.value, 0);
    });

    testWidgets('الضغط على الشخصية يغير الغيمة كذلك', (tester) async {
      await _pump(tester);
      await tester.tapAt(tester.getCenter(find.byType(ThinkingScene)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(_answer(tester).value, 1);
    });

    testWidgets('مع تعطيل الحركات يتغير الكلام فوراً ويرجع', (tester) async {
      await _pump(tester, disableAnimations: true);
      final answer = _answer(tester);
      await _pressCloud(tester);
      expect(answer.value, 1);
      await tester.pump(const Duration(milliseconds: 2800));
      expect(answer.value, 0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('الخروج من الصفحة أثناء الكلام لا يترك شيئاً يعمل', (tester) async {
      await _pump(tester);
      await _pressCloud(tester);
      await tester.tap(_backKey);
      await _settle(tester);
      expect(find.byType(AccountTypeScreen), findsNothing);
    });

    testWidgets('زر الرجوع لا يغير الغيمة', (tester) async {
      await _pump(tester);
      final answer = _answer(tester);
      await tester.tap(_backKey);
      await tester.pump();
      expect(answer.value, 0);
    });
  });

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

  testWidgets('الشاشة القصيرة تعرض الزرين والخصوصية بالسحب', (tester) async {
    await _pump(tester, size: const Size(800, 300));
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
    await tester.pump();
    expect(tester.getRect(_key('زبون')).bottom, lessThan(300));
    expect(tester.getRect(find.text(_privacy)).bottom, lessThan(300));
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
    test('بلا ضغط تبقى تفكر طوال الوقت: المصباح مطفأ والوجه والغيمة لا يتغيران', () {
      for (var time = 0.0; time < ThinkingPose.cycle * 3; time += .05) {
        final pose = ThinkingPose(time);
        expect(pose.idea, 0);
        expect(pose.mouthOpen, 0);
        expect(pose.questionSize, 1);
        expect(pose.answerSize, 0);
        expect(pose.cloudSize, 1);
        // الحاجبان يتحركان قليلاً وهو يفكر، ولا يرتفعان ارتفاع الفكرة.
        expect(pose.leftBrowLift.abs(), lessThanOrEqualTo(.3));
        expect(pose.rightBrowLift, lessThanOrEqualTo(.9));
      }
    });

    test('الضغط يأتي بالفكرة: يضيء المصباح وينفتح الفم وتتبدل الغيمة', () {
      const answered = ThinkingPose(3, answer: 1);
      expect(answered.questionSize, 0);
      expect(answered.answerSize, 1);
      expect(answered.idea, 1);
      expect(answered.mouthOpen, 1);
      expect(answered.rightBrowLift, greaterThan(const ThinkingPose(3).rightBrowLift));
    });

    test('علامة الاستفهام تختفي أولاً ثم يظهر الكلام، فلا يتراكبان', () {
      expect(const ThinkingPose(3, answer: .3).questionSize, greaterThan(0));
      expect(const ThinkingPose(3, answer: .3).answerSize, 0);
      expect(const ThinkingPose(3, answer: .6).questionSize, 0);
      expect(const ThinkingPose(3, answer: .6).answerSize, greaterThan(0));
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
      expect(after.headTilt, closeTo(before.headTilt, .001));
      expect(after.bodyLift, closeTo(before.bodyLift, .01));
      expect(after.blink, closeTo(before.blink, .001));
      expect(after.handTap, closeTo(before.handTap, .001));
      expect(after.eyes.dy, closeTo(before.eyes.dy, .01));
    });
  });
}
