import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jaik/core/theme.dart';
import 'package:jaik/data/database.dart';
import 'package:jaik/data/models.dart';
import 'package:jaik/state/app_state.dart';
import 'package:jaik/ui/auth/login_screen.dart';
import 'package:jaik/ui/auth/push_key.dart';
import 'package:jaik/ui/auth/raised_field.dart';
import 'package:jaik/ui/auth/register_screen.dart';
import 'package:jaik/ui/widgets/ui.dart';

import 'fake_repository.dart';

class _Repo extends FakeRepo {
  _Repo({this.phoneTaken = false});

  final bool phoneTaken;
  final created = <AppUser>[];

  @override
  Future<bool> phoneExists(String phone) async => phoneTaken;

  @override
  Future<int> createUser(AppUser user) async {
    created.add(user);
    return 1;
  }
}

class _SlowRepo extends _Repo {
  final answer = Completer<bool>();

  @override
  Future<bool> phoneExists(String phone) => answer.future;
}

Future<void> _pump(
  WidgetTester tester,
  _Repo repo, {
  String? phone,
  Size size = const Size(412, 1600),
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: AppState(repository: repo),
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RegisterScreen(initialPhone: phone)),
                ),
                child: const Text('الشاشة الأولى'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('الشاشة الأولى'));
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.byType(TextField).at(_fieldOrder.indexOf(label));

const _fieldOrder = ['الاسم', 'الهاتف', 'العنوان', 'المرور', 'التأكيد'];

const _shortPassword = 'كلمة المرور 6 أحرف على الأقل';
const _mismatch = 'كلمتا المرور غير متطابقتين';

Future<void> _chooseCity(WidgetTester tester, String city) async {
  await tester.ensureVisible(find.byType(RaisedPicker));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(RaisedPicker));
  await tester.pumpAndSettle();
  await tester.tap(find.text(city).last);
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester, {String? city = 'بغداد'}) async {
  await tester.enterText(_field('الاسم'), 'كرار عبد الله');
  await tester.enterText(_field('الهاتف'), '07701234567');
  await tester.enterText(_field('العنوان'), 'الكرادة');
  await tester.enterText(_field('المرور'), 'secret1');
  await tester.enterText(_field('التأكيد'), 'secret1');
  if (city != null) await _chooseCity(tester, city);
}

/// لون إطار الخانة كما يُرسم: بعد طبقتي العمق والوجه.
void _expectBorder(WidgetTester tester, Finder field, Color color) {
  final box = find.descendant(of: field, matching: find.byType(CustomPaint)).first;
  expect(tester.renderObject(box), paints..rrect()..rrect()..rrect(color: color));
}

/// هل النقطة الحمراء ظاهرة بجانب هذا العنوان؟
bool _starShown(WidgetTester tester, String label) {
  final mark = find.descendant(
    of: find.widgetWithText(FieldLabel, label),
    matching: find.byType(Opacity),
  );
  return tester.widget<Opacity>(mark).opacity == 1;
}

bool _hidden(WidgetTester tester, String label) =>
    tester.widget<TextField>(_field(label)).obscureText;

void main() {
  testWidgets('الصفحة بخانات صفحة الحرفي وزرها الأصفر', (tester) async {
    await _pump(tester, _Repo());
    expect(find.byType(RaisedField), findsNWidgets(5));
    expect(find.byType(RaisedPicker), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);

    final key = tester.widget<PushKeyButton>(find.byType(PushKeyButton));
    expect(key.label, 'إنشاء الحساب');
    expect(key.yellow, isTrue);
  });

  testWidgets('الطلب الكامل ينشئ الحساب بالمحافظة المختارة ويرجع إلى الشاشة الأولى', (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await _fill(tester);

    await tester.tap(find.byType(RaisedPicker));
    await tester.pumpAndSettle();
    expect(tester.widget<RaisedPicker>(find.byType(RaisedPicker)).open, isTrue);
    await tester.tap(find.text('البصرة'));
    await tester.pumpAndSettle();
    expect(tester.widget<RaisedPicker>(find.byType(RaisedPicker)).open, isFalse);
    expect(tester.widget<RaisedPicker>(find.byType(RaisedPicker)).value, 'البصرة');

    await tester.tap(find.text('إنشاء الحساب').last);
    await tester.pumpAndSettle();

    final user = repo.created.single;
    expect(user.name, 'كرار عبد الله');
    expect(user.phone, '07701234567');
    expect(user.city, 'البصرة');
    expect(user.address, 'الكرادة');
    expect(user.passwordHash, hashPassword('secret1'));
    expect(find.byType(RegisterScreen), findsNothing);
    expect(find.text('الشاشة الأولى'), findsOneWidget);
  });

  testWidgets('الرقم القادم من الشاشة الأولى يظهر في خانته', (tester) async {
    await _pump(tester, _Repo(), phone: '07711112222');
    expect(tester.widget<TextField>(_field('الهاتف')).controller!.text, '07711112222');
  });

  testWidgets('المعلومات الناقصة والخطأ تظهر رسائلها ولا تنشئ حساباً', (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);

    await tester.tap(find.text('إنشاء الحساب').last);
    await tester.pump();
    expect(find.text('أدخل الاسم الكامل'), findsOneWidget);
    expect(find.text('أدخل رقم الهاتف'), findsOneWidget);
    expect(find.text('كلمة المرور 6 أحرف على الأقل'), findsOneWidget);
    expect(find.text('اختر محافظتك'), findsOneWidget);

    await tester.enterText(_field('الهاتف'), '123');
    await tester.enterText(_field('المرور'), 'secret1');
    await tester.enterText(_field('التأكيد'), 'secret2');
    await tester.tap(find.text('إنشاء الحساب').last);
    await tester.pump();
    expect(find.text('رقم غير صالح (11 رقم يبدأ بـ 07)'), findsOneWidget);
    expect(find.text('كلمتا المرور غير متطابقتين'), findsOneWidget);
    expect(repo.created, isEmpty);
    await tester.pumpAndSettle();
  });

  testWidgets('حمرة كلمة المرور تختفي بمجرد الكتابة، وترجع إذا بقيت قصيرة عند الإنشاء', (tester) async {
    await _pump(tester, _Repo());
    await tester.tap(find.text('إنشاء الحساب').last);
    await tester.pumpAndSettle();
    expect(find.text(_shortPassword), findsOneWidget);

    await tester.enterText(_field('المرور'), '1');
    await tester.pumpAndSettle();
    expect(find.text(_shortPassword), findsNothing);

    await tester.tap(find.text('إنشاء الحساب').last);
    await tester.pumpAndSettle();
    expect(find.text(_shortPassword), findsOneWidget);
  });

  testWidgets('حمرة التأكيد تختفي عند الكتابة فيه أو عند تعديل كلمة المرور', (tester) async {
    await _pump(tester, _Repo());
    await tester.enterText(_field('المرور'), 'secret1');
    await tester.enterText(_field('التأكيد'), 'secret2');
    await tester.tap(find.text('إنشاء الحساب').last);
    await tester.pumpAndSettle();
    expect(find.text(_mismatch), findsOneWidget);

    await tester.enterText(_field('التأكيد'), 's');
    await tester.pumpAndSettle();
    expect(find.text(_mismatch), findsNothing);

    await tester.tap(find.text('إنشاء الحساب').last);
    await tester.pumpAndSettle();
    expect(find.text(_mismatch), findsOneWidget);

    await tester.enterText(_field('المرور'), 'secret9');
    await tester.pumpAndSettle();
    expect(find.text(_mismatch), findsNothing);
  });

  testWidgets('تحريك المؤشر بلا كتابة لا يخفي الحمرة', (tester) async {
    await _pump(tester, _Repo());
    await tester.enterText(_field('المرور'), 'secret1');
    await tester.enterText(_field('التأكيد'), 'secret2');
    await tester.tap(find.text('إنشاء الحساب').last);
    await tester.pumpAndSettle();

    for (final label in ['المرور', 'التأكيد']) {
      tester.widget<TextField>(_field(label)).controller!.selection =
          const TextSelection.collapsed(offset: 1);
    }
    await tester.pumpAndSettle();
    expect(find.text(_mismatch), findsOneWidget);
  });

  testWidgets('حمرة الاسم والرقم تختفي بمجرد الكتابة', (tester) async {
    await _pump(tester, _Repo());
    await tester.tap(find.text('إنشاء الحساب').last);
    await tester.pumpAndSettle();

    await tester.enterText(_field('الاسم'), 'ك');
    await tester.enterText(_field('الهاتف'), '0');
    await tester.pumpAndSettle();
    expect(find.text('أدخل الاسم الكامل'), findsNothing);
    expect(find.text('أدخل رقم الهاتف'), findsNothing);
  });

  for (final typed in const [
    '7701234567',
    '٠٧٧٠١٢٣٤٥٦٧',
    '۰۷۷۰۱۲۳۴۵۶۷',
    '+964 770 123 4567',
    '0770 123 4567',
  ]) {
    testWidgets('الرقم $typed يُقبل ويُحفظ بصيغة واحدة', (tester) async {
      final repo = _Repo();
      await _pump(tester, repo);
      await _fill(tester);
      await tester.enterText(_field('الهاتف'), typed);
      await tester.tap(find.text('إنشاء الحساب').last);
      await tester.pumpAndSettle();
      expect(find.text('رقم غير صالح (11 رقم يبدأ بـ 07)'), findsNothing);
      expect(repo.created.single.phone, '07701234567');
    });
  }

  testWidgets('الصفحة تبدأ بلا محافظة، ولا يُنشأ الحساب قبل اختيارها', (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    expect(find.text('بغداد'), findsNothing);
    expect(tester.widget<RaisedPicker>(find.byType(RaisedPicker)).value, isNull);
    expect(find.text('اختر المحافظة'), findsOneWidget);

    await _fill(tester, city: null);
    await tester.tap(find.text('إنشاء الحساب').last);
    await tester.pumpAndSettle();
    expect(find.text('اختر محافظتك'), findsOneWidget);
    expect(repo.created, isEmpty);

    await _chooseCity(tester, 'النجف');
    expect(find.text('اختر محافظتك'), findsNothing);
    await tester.tap(find.text('إنشاء الحساب').last);
    await tester.pumpAndSettle();
    expect(repo.created.single.city, 'النجف');
  });

  testWidgets('الإنشاء مع خانة ناقصة ينقل الصفحة إلى أول خانة خطأ', (tester) async {
    await _pump(tester, _Repo(), size: const Size(412, 600));
    final key = find.byType(PushKeyButton);
    await tester.ensureVisible(key);
    await tester.pumpAndSettle();
    final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
    expect(tester.getTopLeft(find.text('الاسم الكامل')).dy, lessThan(appBarBottom));

    await tester.tap(key);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('الاسم الكامل')).dy, greaterThanOrEqualTo(appBarBottom));
    expect(tester.getBottomLeft(find.text('أدخل الاسم الكامل')).dy, lessThanOrEqualTo(600));
  });

  testWidgets('الصفحة تنتقل إلى المحافظة إذا كانت هي الناقصة', (tester) async {
    final repo = _Repo();
    await _pump(tester, repo, size: const Size(412, 600));
    await _fill(tester, city: null);
    final key = find.byType(PushKeyButton);
    await tester.ensureVisible(key);
    await tester.pumpAndSettle();

    await tester.tap(key);
    await tester.pumpAndSettle();
    final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
    expect(tester.getTopLeft(find.text('المحافظة')).dy, greaterThanOrEqualTo(appBarBottom));
    expect(tester.getBottomLeft(find.text('اختر محافظتك')).dy, lessThanOrEqualTo(600));
    expect(repo.created, isEmpty);
  });

  testWidgets('الصفحة لا تتحرك إذا كانت الخانة الخطأ ظاهرة', (tester) async {
    await _pump(tester, _Repo(), size: const Size(412, 600));
    await _fill(tester);
    await tester.enterText(_field('التأكيد'), 'different');
    final key = find.byType(PushKeyButton);
    await tester.ensureVisible(key);
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(find.text('تأكيد كلمة المرور'));

    await tester.tap(key);
    await tester.pumpAndSettle();
    expect(find.text(_mismatch), findsOneWidget);
    expect(tester.getTopLeft(find.text('تأكيد كلمة المرور')), before);
  });

  testWidgets('الكتابة وإطارها بالأسود، والأحمر للخطأ فقط', (tester) async {
    await _pump(tester, _Repo());
    await tester.tap(find.text('إنشاء الحساب').last);
    await tester.pumpAndSettle();
    final name = find.byType(RaisedField).at(0);
    _expectBorder(tester, name, const Color(0xFFFF4D4D));

    await tester.enterText(_field('الاسم'), 'كرار');
    await tester.pumpAndSettle();
    _expectBorder(tester, name, AppColors.ink);
    final field = tester.widget<TextField>(_field('الاسم'));
    expect(field.style!.color, AppColors.ink);
    expect(field.cursorColor, AppColors.ink);

    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pumpAndSettle();
    _expectBorder(tester, name, const Color(0xFFDDDDDD));
  });

  testWidgets('المحافظة المختارة والعين والسهم بالأسود', (tester) async {
    await _pump(tester, _Repo());
    await _chooseCity(tester, 'البصرة');
    expect(tester.widget<Text>(find.text('البصرة')).style!.color, AppColors.ink);
    expect(tester.widget<Icon>(find.byIcon(Icons.expand_more_rounded)).color, AppColors.ink);
    expect(tester.widget<Icon>(find.byIcon(Icons.visibility_off_rounded)).color, AppColors.ink);
  });

  testWidgets('رسالة الرقم المستخدم تختفي بتعديل الرقم، لا بتحريك المؤشر', (tester) async {
    await _pump(tester, _Repo(phoneTaken: true));
    await _fill(tester);
    await tester.tap(find.text('إنشاء الحساب').last);
    await tester.pumpAndSettle();
    expect(find.text('رقم الهاتف مستخدم مسبقاً'), findsOneWidget);

    tester.widget<TextField>(_field('الهاتف')).controller!.selection =
        const TextSelection.collapsed(offset: 1);
    await tester.pumpAndSettle();
    expect(find.text('رقم الهاتف مستخدم مسبقاً'), findsOneWidget);

    await tester.enterText(_field('الهاتف'), '07701234568');
    await tester.pumpAndSettle();
    expect(find.text('رقم الهاتف مستخدم مسبقاً'), findsNothing);
  });

  testWidgets('كل خانات الكتابة بالأسود لا الاسم فقط، وفي الليل بلون فاتح مقروء', (tester) async {
    await _pump(tester, _Repo());
    for (final label in _fieldOrder) {
      expect(tester.widget<TextField>(_field(label)).style!.color, AppColors.ink, reason: label);
    }

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: AppState(repository: _Repo()),
        child: MaterialApp(
          theme: AppTheme.dark(),
          builder: (context, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
          home: const RegisterScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final label in _fieldOrder) {
      expect(
        tester.widget<TextField>(_field(label)).style!.color,
        const Color(0xFFF4F4EE),
        reason: label,
      );
    }
  });

  testWidgets('النقطة الحمراء تختفي بملء الخانة وترجع بتفريغها، دون أن تتحرك الصفحة', (tester) async {
    await _pump(tester, _Repo());
    const labels = {
      'الاسم الكامل': 'الاسم',
      'رقم الهاتف': 'الهاتف',
      'كلمة المرور': 'المرور',
      'تأكيد كلمة المرور': 'التأكيد',
    };
    final below = find.text('تأكيد كلمة المرور');
    final top = tester.getTopLeft(below);

    for (final MapEntry(key: label, value: field) in labels.entries) {
      expect(_starShown(tester, label), isTrue, reason: label);
      await tester.enterText(_field(field), 'ك');
      await tester.pump();
      expect(_starShown(tester, label), isFalse, reason: label);
    }
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(below), top);

    expect(_starShown(tester, 'المحافظة'), isTrue);
    await _chooseCity(tester, 'البصرة');
    expect(_starShown(tester, 'المحافظة'), isFalse);

    await tester.enterText(_field('الاسم'), '');
    await tester.pump();
    expect(_starShown(tester, 'الاسم الكامل'), isTrue);
    await tester.enterText(_field('الاسم'), '   ');
    await tester.pump();
    expect(_starShown(tester, 'الاسم الكامل'), isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('الرقم القادم من الشاشة الأولى يبدأ بلا نقطة حمراء', (tester) async {
    await _pump(tester, _Repo(), phone: '07711112222');
    expect(_starShown(tester, 'رقم الهاتف'), isFalse);
    expect(_starShown(tester, 'الاسم الكامل'), isTrue);
  });

  testWidgets('زر العين يظهر كلمة المرور ويخفيها، وخانة التأكيد تبقى مخفية', (tester) async {
    await _pump(tester, _Repo());
    expect(_hidden(tester, 'المرور'), isTrue);
    expect(_hidden(tester, 'التأكيد'), isTrue);
    expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_off_rounded));
    await tester.pump();
    expect(_hidden(tester, 'المرور'), isFalse);
    expect(_hidden(tester, 'التأكيد'), isTrue);
    expect(tester.testTextInput.isVisible, isFalse);

    // المنطقة حول العين تكفي للمس، حتى عند حافة الخانة.
    final box = tester.getTopLeft(find.byType(RaisedField).at(3));
    await tester.tapAt(box + const Offset(6, 6));
    await tester.pump();
    expect(_hidden(tester, 'المرور'), isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('العين لا تغير ارتفاع الخانة ولا تغطي الكتابة', (tester) async {
    await _pump(tester, _Repo());
    final withEye = find.byType(RaisedField).at(3);
    final plain = find.byType(RaisedField).at(4);
    expect(tester.getSize(withEye), tester.getSize(plain));

    final eye = tester.getRect(find.byIcon(Icons.visibility_off_rounded));
    expect(tester.getRect(_field('المرور')).left, greaterThan(eye.right));
  });

  testWidgets('زر الإنشاء يبقى منخفضاً أثناء الانتظار ولا ينشئ الحساب مرتين', (tester) async {
    final repo = _SlowRepo();
    await _pump(tester, repo);
    await _fill(tester);

    await tester.tap(find.text('إنشاء الحساب').last);
    await tester.pump();
    expect(tester.widget<PushKeyButton>(find.byType(PushKeyButton)).loading, isTrue);
    await tester.tap(find.byType(PushKeyButton));
    await tester.pump();

    repo.answer.complete(false);
    await tester.pumpAndSettle();
    expect(repo.created, hasLength(1));
  });

  testWidgets('رابط تسجيل الدخول يبقى ويفتح صفحة الدخول', (tester) async {
    await _pump(tester, _Repo());
    expect(find.text('لديك حساب؟'), findsOneWidget);
    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(RegisterScreen), findsNothing);
  });
}
