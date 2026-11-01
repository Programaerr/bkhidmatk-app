import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jaik/core/theme.dart';
import 'package:jaik/state/app_state.dart';
import 'package:jaik/ui/auth/craftsman_screen.dart';
import 'package:jaik/ui/auth/day_night_switch.dart';
import 'package:jaik/ui/auth/login_screen.dart';
import 'package:jaik/ui/auth/push_key.dart';
import 'package:jaik/ui/auth/register_screen.dart';
import 'package:jaik/ui/auth/social_marks.dart';
import 'package:jaik/ui/auth/truck_scene.dart';
import 'package:jaik/ui/auth/welcome_screen.dart';

import 'fake_repository.dart';

Future<void> _pump(
  WidgetTester tester, {
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: AppState(repository: FakeRepo()),
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ar'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: disableAnimations),
          child:
              Directionality(textDirection: TextDirection.rtl, child: child!),
        ),
        home: const WelcomeScreen(),
      ),
    ),
  );
  await tester.pump();
}

/// يضبط مقاس الشاشة ويرجعه بعد انتهاء الاختبار.
void _useScreen(WidgetTester tester, Size size, {double statusBar = 0}) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..padding = FakeViewPadding(top: statusBar)
    ..viewPadding = FakeViewPadding(top: statusBar);
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('زر اللغة يبدّل نصوص الشاشة وكلام السائق، ثم يرجعها',
      (tester) async {
    await _pump(tester);
    TruckScenePainter scene() => tester
        .widget<CustomPaint>(
          find.descendant(
              of: find.byType(TruckScene), matching: find.byType(CustomPaint)),
        )
        .painter! as TruckScenePainter;
    expect(find.text('AR'), findsOneWidget);
    expect(scene().english, isFalse);

    await tester.tap(find.text('AR'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('EN'), findsOneWidget);
    expect(find.text('AR'), findsNothing);
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Craftsman'), findsOneWidget);
    expect(find.text('Have an account?'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Contact us'), findsOneWidget);
    expect(find.text('كزبون'), findsNothing);
    expect(scene().english, isTrue);

    await tester.tap(find.text('EN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('AR'), findsOneWidget);
    expect(find.text('كزبون'), findsOneWidget);
    expect(scene().english, isFalse);
  });

  testWidgets('زر الليل والنهار يغيّر ثيم التطبيق ولون الشاشة بالتدريج ثم يرجع',
      (tester) async {
    await _pump(tester);
    final state = tester.element(find.byType(WelcomeScreen)).read<AppState>();
    double night() =>
        tester.widget<PushKey>(find.byType(PushKey).first).night.value;
    Color? ground() => tester
        .widget<ColoredBox>(
          find
              .descendant(
                  of: find.byType(WelcomeScreen),
                  matching: find.byType(ColoredBox))
              .first,
        )
        .color;
    final dayGround = ground();
    expect(night(), 0);

    await tester.tap(find.bySemanticsLabel('الوضع الليلي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(state.themeMode, ThemeMode.dark);
    expect(night(), inExclusiveRange(0, 1));

    await tester.pump(const Duration(milliseconds: 300));
    expect(night(), 1);
    expect(tester.widget<DayNightSwitch>(find.byType(DayNightSwitch)).night,
        isTrue);
    expect(ground(), Colors.black);
    // زر اللغة فوق الجهة الصفراء، فيبقى لونه داكناً في الليل أيضاً.
    expect(tester.widget<Text>(find.text('AR')).style!.color,
        const Color(0xFF383838));

    await tester.tap(find.bySemanticsLabel('الوضع الليلي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(state.themeMode, ThemeMode.light);
    expect(night(), 0);
    expect(ground(), dayGround);
  });

  test('اللغة والوضع المختاران يرجعان عند فتح التطبيق من جديد', () async {
    final first = AppState(repository: FakeRepo());
    await first.setEnglish(true);
    await first.setTheme(true);

    final next = AppState(repository: FakeRepo());
    expect(next.english, isFalse);
    await next.boot();
    expect(next.english, isTrue);
    expect(next.themeMode, ThemeMode.dark);
  });

  testWidgets('الخصوصية والتواصل وأزرار المنصات تحت زر الزبون بترتيب التصميم',
      (tester) async {
    await _pump(tester);
    final customer = tester.getRect(find.byType(PushKey).at(0));
    final privacy = tester.getRect(find.text('سياسة و الخصوصية'));
    final facebook = tester.getRect(find.byType(PushKey).at(3));
    final instagram = tester.getRect(find.byType(PushKey).at(4));
    final tiktok = tester.getRect(find.byType(PushKey).at(5));
    final contact = tester.getRect(find.text('تواصلوا معنى'));

    expect(privacy.top, greaterThan(customer.bottom));
    expect(facebook.top, greaterThan(privacy.bottom));
    expect(contact.top, greaterThan(facebook.bottom));
    expect(facebook.left, greaterThan(instagram.right));
    expect(instagram.left, greaterThan(tiktok.right));

    final marks = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((paint) => paint.painter)
        .whereType<SocialMarkPainter>()
        .map((painter) => painter.mark);
    expect(marks, SocialMark.values);
    for (final name in ['فيسبوك', 'انستغرام', 'تيك توك']) {
      expect(find.bySemanticsLabel(name), findsOneWidget);
    }
  });

  testWidgets('زر الحساب صف كامل تحت زري الزبون والحرفي، وفوق خط الخصوصية',
      (tester) async {
    await _pump(tester);
    final customer = tester.getRect(find.byType(PushKey).at(0));
    final craftsman = tester.getRect(find.byType(PushKey).at(1));
    final account = tester.getRect(
      find.ancestor(
          of: find.text('هل لديك حساب'), matching: find.byType(PushKey)),
    );

    expect(account.left, craftsman.left);
    expect(account.right, customer.right);
    expect(account.height, customer.height);
    expect(account.top, greaterThan(customer.bottom));
    expect(tester.getRect(find.text('سياسة و الخصوصية')).top,
        greaterThan(account.bottom));
  });

  testWidgets('لا رمز عراق ولا خانة رقم ولا خط بينهما في الشاشة الأولى',
      (tester) async {
    await _pump(tester);
    expect(find.text('🇮🇶 +964'), findsNothing);
    expect(find.text('رقم الموبايل'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(PushKey), findsNWidgets(6));
    expect(
      find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == const Color(0xFFD3D0C2)),
      findsNothing,
    );
  });

  for (final size in const [Size(392, 825), Size(360, 780), Size(412, 915)]) {
    testWidgets('الفراغ فوق الأزرار مثل الفراغ تحتها في هاتف $size',
        (tester) async {
      _useScreen(tester, size);
      await _pump(tester);
      final curve = tester.getRect(find.byType(TruckScene)).bottom;
      final firstRow = tester.getRect(find.byType(PushKey).at(0)).top;
      final lastLine = tester.getRect(
        find
            .byWidgetPredicate(
                (w) => w is ColoredBox && w.color == const Color(0xFFBEB9B3))
            .last,
      );

      // الفراغ السفلي يمتد إلى أيقونات شريط التنقل، وهي تحت حافة التطبيق بنحو 14.
      expect(firstRow - curve, closeTo(size.height + 14 - lastLine.bottom, 1));
    });
  }

  testWidgets('زر الحساب وحده أصفر، وكتابته داكنة نهاراً وليلاً',
      (tester) async {
    await _pump(tester);
    expect(
      tester.widgetList<PushKey>(find.byType(PushKey)).map((key) => key.yellow),
      [false, false, true, false, false, false],
    );

    Color ink() => tester.widget<Text>(find.text('هل لديك حساب')).style!.color!;
    expect(ink(), const Color(0xFF263238));

    tester.element(find.byType(WelcomeScreen)).read<AppState>().setTheme(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.widget<PushKey>(find.byType(PushKey).first).night.value, 1);
    expect(ink(), const Color(0xFF263238));
  });

  testWidgets('زر الحساب يفتح صفحة الدخول بسرعة', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('هل لديك حساب'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final page = tester.element(find.byType(LoginScreen));
    expect(ModalRoute.of(page)!.animation!.value, 1);
  });

  testWidgets('زر كزبون يفتح صفحة إنشاء الحساب بسرعة', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('كزبون'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final page = tester.element(find.byType(RegisterScreen));
    expect(ModalRoute.of(page)!.animation!.value, 1);
  });

  testWidgets('في أصغر هاتف يظهر كل شيء، وزرا الأعلى تحت شريط الحالة',
      (tester) async {
    _useScreen(tester, const Size(320, 568), statusBar: 24);
    await _pump(tester);
    final language = tester.getRect(find.text('AR'));
    final dayNight = tester.getRect(find.byType(DayNightSwitch));

    expect(language.left, greaterThan(0));
    expect(language.top, greaterThan(24));
    expect(dayNight.right, lessThan(320));
    expect(dayNight.top, greaterThanOrEqualTo(24 + 20));
    expect(tester.getRect(find.text('تواصلوا معنى')).bottom, lessThan(568));
  });

  testWidgets('زر حرفي يسار زر الزبون بنفس مقاسه، ويفتح صفحة الحرفي',
      (tester) async {
    await _pump(tester);
    final customer = tester.getRect(find.byType(PushKey).at(0));
    final craftsman = tester.getRect(find.byType(PushKey).at(1));
    expect(craftsman.top, customer.top);
    expect(craftsman.width, closeTo(customer.width, .5));
    expect(craftsman.right, lessThan(customer.left));

    await tester.tap(find.text('حرفي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CraftsmanScreen), findsOneWidget);

    await tester.ensureVisible(find.text('عودة كزبون'));
    await tester.pump();
    await tester.tap(find.text('عودة كزبون'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.byType(CraftsmanScreen), findsNothing);
    expect(find.text('حرفي'), findsOneWidget);
  });

  testWidgets('صفحة الحرفي تفتح وترجع خلال 200 مللي ثانية', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('حرفي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final page = tester.element(find.byType(CraftsmanScreen));
    expect(ModalRoute.of(page)!.animation!.value, 1);

    Navigator.of(page).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 201));
    await tester.pump();
    expect(find.byType(CraftsmanScreen), findsNothing);
  });

  testWidgets('زرا صفحة الحرفي بنفس ارتفاع زر الزبون وخطه ولونه',
      (tester) async {
    await _pump(tester);
    final customerKey = find.byType(PushKey).at(0);
    final customerHeight = tester.getSize(customerKey).height;
    final customerUnit = tester.widget<PushKey>(customerKey).unit;
    final customerFace = tester.widget<PushKey>(customerKey).faceHeight;
    final customerText = tester.widget<Text>(find.text('كزبون')).style!;

    await tester.tap(find.text('حرفي'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    for (final label in ['إرسال الطلب إلى الشركة', 'عودة كزبون']) {
      final key =
          find.ancestor(of: find.text(label), matching: find.byType(PushKey));
      expect(tester.getSize(key).height, closeTo(customerHeight, .01));
      expect(tester.widget<PushKey>(key).unit, customerUnit);
      expect(tester.widget<PushKey>(key).faceHeight, customerFace);
      final text = tester.widget<Text>(find.text(label)).style!;
      expect(text.fontFamily, customerText.fontFamily);
      expect(text.fontSize, customerText.fontSize);
      expect(text.height, customerText.height);
      expect(text.fontWeight, customerText.fontWeight);
      expect(text.color, customerText.color);
    }
  });

  testWidgets('الكرة الأرضية بجانب رمز اللغة، والضغط عليها يبدّل اللغة',
      (tester) async {
    await _pump(tester);
    final globe = find.byIcon(Icons.public);
    expect(globe, findsOneWidget);
    expect(tester.getRect(globe).right,
        lessThanOrEqualTo(tester.getRect(find.text('AR')).left));

    await tester.tap(globe);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('EN'), findsOneWidget);
  });

  testWidgets('الشاشة القصيرة تعرض بقية العناصر بالسحب', (tester) async {
    _useScreen(tester, const Size(800, 360));
    await _pump(tester);
    final contact = find.text('تواصلوا معنى');
    expect(tester.getRect(contact).top, greaterThan(360));

    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -300));
    await tester.pump();
    expect(tester.getRect(contact).bottom, lessThan(360));
  });

  testWidgets('المشهد يتحرك في الوضع العادي', (tester) async {
    await _pump(tester);
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('المشهد يثبت إذا عطّل المستخدم الحركات من الجهاز',
      (tester) async {
    await _pump(tester, disableAnimations: true);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('الزر ينخفض عند اللمس، ويكون مرتفعاً عند الرجوع إلى الشاشة',
      (tester) async {
    await _pump(tester);
    final label = find.text('كزبون');
    final up = tester.getTopLeft(label).dy;

    final finger = await tester.startGesture(tester.getCenter(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.getTopLeft(label).dy, closeTo(up + 6, .5));

    await finger.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    Navigator.of(tester.element(find.byType(RegisterScreen))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.getTopLeft(label).dy, closeTo(up, .5));
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

  testWidgets('الضغط على السيارة يسرعها، والضغط خارجها لا يغيّر شيئاً',
      (tester) async {
    await _pump(tester);
    VanDirector director() => (tester
            .widget<CustomPaint>(
              find.descendant(
                  of: find.byType(TruckScene),
                  matching: find.byType(CustomPaint)),
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
    expect(parseSvgPath('M0,0h10v10h-10Z').getBounds(),
        const Rect.fromLTRB(0, 0, 10, 10));
    expect(parseSvgPath('M1-2l.5.5-1.5 1.5Z').getBounds(),
        const Rect.fromLTRB(0, -2, 1.5, 0));

    final circle =
        parseSvgPath('M0,5A5,5,0,1,0,10,5A5,5,0,1,0,0,5Z').getBounds();
    expect(circle.width, closeTo(10, .01));
    expect(circle.height, closeTo(10, .01));
  });
}
