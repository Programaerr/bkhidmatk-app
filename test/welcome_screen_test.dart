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

/// يضبط مقاس الشاشة ويرجعه بعد انتهاء الاختبار.
void _useScreen(WidgetTester tester, Size size, {double statusBar = 0, double keyboard = 0}) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..padding = FakeViewPadding(top: statusBar)
    ..viewPadding = FakeViewPadding(top: statusBar)
    ..viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('زر اللغة يبدّل نصوص الشاشة وكلام السائق، ثم يرجعها', (tester) async {
    await _pump(tester);
    TruckScenePainter scene() => tester
        .widget<CustomPaint>(
          find.descendant(of: find.byType(TruckScene), matching: find.byType(CustomPaint)),
        )
        .painter! as TruckScenePainter;
    expect(find.text('AR'), findsOneWidget);
    expect(scene().english, isFalse);

    await tester.tap(find.text('AR'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('EN'), findsOneWidget);
    expect(find.text('AR'), findsNothing);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Craftsman'), findsOneWidget);
    expect(find.text('Mobile number'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Contact us'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsNothing);
    expect(scene().english, isTrue);

    await tester.tap(find.text('EN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('AR'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(scene().english, isFalse);
  });

  testWidgets('زر الليل والنهار يغيّر ثيم التطبيق ولون الشاشة بالتدريج ثم يرجع', (tester) async {
    await _pump(tester);
    final state = tester.element(find.byType(WelcomeScreen)).read<AppState>();
    double night() => tester.widget<PushKey>(find.byType(PushKey).first).night.value;
    Color? ground() => tester
        .widget<ColoredBox>(
          find.descendant(of: find.byType(WelcomeScreen), matching: find.byType(ColoredBox)).first,
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
    expect(tester.widget<DayNightSwitch>(find.byType(DayNightSwitch)).night, isTrue);
    expect(ground(), Colors.black);
    // زر اللغة فوق الجهة الصفراء، فيبقى لونه داكناً في الليل أيضاً.
    expect(tester.widget<Text>(find.text('AR')).style!.color, const Color(0xFF383838));

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

  testWidgets('الخصوصية والتواصل وأزرار المنصات تحت زر الدخول بترتيب التصميم', (tester) async {
    await _pump(tester);
    final login = tester.getRect(find.byType(PushKey).at(2));
    final privacy = tester.getRect(find.text('سياسة و الخصوصية'));
    final facebook = tester.getRect(find.byType(PushKey).at(4));
    final instagram = tester.getRect(find.byType(PushKey).at(5));
    final tiktok = tester.getRect(find.byType(PushKey).at(6));
    final contact = tester.getRect(find.text('تواصلوا معنى'));

    expect(privacy.top, greaterThan(login.bottom));
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

  testWidgets('كل العناصر داخل أصغر هاتف، وزرا الأعلى تحت شريط الحالة', (tester) async {
    _useScreen(tester, const Size(320, 568), statusBar: 24);
    await _pump(tester);
    final language = tester.getRect(find.text('AR'));
    final dayNight = tester.getRect(find.byType(DayNightSwitch));
    final contact = tester.getRect(find.text('تواصلوا معنى'));

    expect(language.left, greaterThan(0));
    expect(language.top, greaterThan(24));
    expect(dayNight.right, lessThan(320));
    expect(dayNight.top, greaterThanOrEqualTo(24 + 20));
    expect(contact.bottom, lessThan(568));
  });

  testWidgets('زر حرفي يسار زر الدخول بنفس مقاسه، ويفتح صفحة الحرفي بالرقم المكتوب', (tester) async {
    await _pump(tester);
    final login = tester.getRect(find.byType(PushKey).at(2));
    final craftsman = tester.getRect(find.byType(PushKey).at(3));
    expect(craftsman.top, login.top);
    expect(craftsman.width, closeTo(login.width, .5));
    expect(craftsman.right, lessThan(login.left));

    // طرفا صف الرقم على طرفي الصف الذي تحته تماماً.
    expect(tester.getRect(find.byType(PushKey).at(1)).right, login.right);
    expect(tester.getRect(find.byType(PushKey).at(0)).left, craftsman.left);

    await tester.enterText(find.byType(TextField), '7701234567');
    await tester.tap(find.text('حرفي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CraftsmanScreen), findsOneWidget);
    expect(
      find.descendant(of: find.byType(CraftsmanScreen), matching: find.text('07701234567')),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('عودة كزبون'));
    await tester.pump();
    await tester.tap(find.text('عودة كزبون'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.byType(CraftsmanScreen), findsNothing);
    expect(find.text('حرفي'), findsOneWidget);
  });

  testWidgets('الكرة الأرضية بجانب رمز اللغة، والضغط عليها يبدّل اللغة', (tester) async {
    await _pump(tester);
    final globe = find.byIcon(Icons.public);
    expect(globe, findsOneWidget);
    expect(tester.getRect(globe).right, lessThanOrEqualTo(tester.getRect(find.text('AR')).left));

    await tester.tap(globe);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('EN'), findsOneWidget);
  });

  testWidgets('صيغة الرقم تذوب ثم يظهر نص الخانة بالتدريج دون قفزة', (tester) async {
    await _pump(tester);
    double level(String text) => tester.widget<Text>(find.text(text)).style!.color!.a;

    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(level('07XX XXX XXXX'), 1);
    expect(find.text('رقم الموبايل'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1300));
    expect(level('07XX XXX XXXX'), inExclusiveRange(0, 1));
    expect(find.text('رقم الموبايل'), findsNothing);

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('07XX XXX XXXX'), findsNothing);
    expect(level('رقم الموبايل'), inExclusiveRange(0, 1));

    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();
    expect(level('رقم الموبايل'), 1);
  });

  testWidgets('الشاشة القصيرة تعرض بقية العناصر بالسحب', (tester) async {
    _useScreen(tester, const Size(800, 360));
    await _pump(tester);
    final contact = find.text('تواصلوا معنى');
    expect(tester.getRect(contact).top, greaterThan(360));

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
    await tester.pump();
    expect(tester.getRect(contact).bottom, lessThan(360));
  });

  testWidgets('لوحة المفاتيح لا تغطي زر الدخول', (tester) async {
    _useScreen(tester, const Size(392, 872), keyboard: 330);
    await _pump(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getRect(find.byType(PushKey).at(2)).bottom, lessThanOrEqualTo(872 - 330));
  });

  for (final size in const [Size(360, 640), Size(392, 872)]) {
    testWidgets('رسالة الخطأ فوق خانة الرقم ولا تغطيها في هاتف $size', (tester) async {
      _useScreen(tester, size);
      await _pump(tester);
      await tester.tap(find.text('تسجيل الدخول'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final message = tester.getRect(find.text('أدخل رقم موبايل عراقي صحيح يبدأ بـ 07'));
      expect(message.bottom, lessThanOrEqualTo(tester.getRect(find.byType(PushKey).at(1)).top));
    });
  }

  testWidgets('الرقم غير العراقي لا ينتقل لشاشة أخرى ويعرض خطأ', (tester) async {
    final repo = await _pump(tester);
    await _submit(tester, '1234567890');

    expect(find.text('أدخل رقم موبايل عراقي صحيح يبدأ بـ 07'), findsOneWidget);
    expect(repo.asked, isEmpty);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(RegisterScreen), findsNothing);
  });

  testWidgets('الخطأ يجعل الخانة حمراء بالكامل ثم تعود ببطء ويختفي الأحمر والرسالة', (tester) async {
    await _pump(tester);
    double alarm() => tester.widget<PushKey>(find.byType(PushKey).at(1)).alarm;
    const message = 'أدخل رقم موبايل عراقي صحيح يبدأ بـ 07';
    expect(alarm(), 0);

    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(alarm(), 1);
    expect(find.text(message), findsOneWidget);
    expect(find.text('07XX XXX XXXX'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1400));
    expect(alarm(), inExclusiveRange(0, 1));

    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump();
    expect(alarm(), 0);
    expect(find.text(message), findsNothing);
    expect(find.text('07XX XXX XXXX'), findsNothing);
    expect(find.text('رقم الموبايل'), findsOneWidget);
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

  testWidgets('علم العراق بجانب الرمز، والزر ينخفض عند اللمس ويعود', (tester) async {
    await _pump(tester);
    expect(find.text('🇮🇶 +964'), findsOneWidget);

    final label = find.text('تسجيل الدخول');
    final up = tester.getTopLeft(label).dy;

    final finger = await tester.startGesture(tester.getCenter(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.getTopLeft(label).dy, closeTo(up + 6, .5));

    await finger.up();
    await tester.pump();
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
