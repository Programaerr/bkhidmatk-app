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

import 'fake_repository.dart';

class _Repo extends FakeRepo {
  final created = <AppUser>[];

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

Future<void> _pump(WidgetTester tester, _Repo repo, {String? phone}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view
    ..physicalSize = const Size(412, 1600)
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

Future<void> _fill(WidgetTester tester) async {
  await tester.enterText(_field('الاسم'), 'كرار عبد الله');
  await tester.enterText(_field('الهاتف'), '07701234567');
  await tester.enterText(_field('العنوان'), 'الكرادة');
  await tester.enterText(_field('المرور'), 'secret1');
  await tester.enterText(_field('التأكيد'), 'secret1');
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
