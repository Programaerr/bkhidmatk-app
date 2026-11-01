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

import 'fake_repository.dart';

const _shortPassword = 'كلمة المرور 6 أحرف على الأقل';
const _wrongPassword = 'كلمة المرور غير صحيحة';

class _Repo extends FakeRepo {
  _Repo({super.customer});

  final asked = <String>[];

  @override
  Future<AppUser?> findUserByPhone(String phone) {
    asked.add(phone);
    return super.findUserByPhone(phone);
  }
}

AppUser _customer() => AppUser(
      id: 1,
      name: 'كرار',
      phone: '07701234567',
      passwordHash: hashPassword('secret1'),
      role: 'customer',
      createdAt: DateTime(2026, 11, 1),
    );

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
                  MaterialPageRoute(builder: (_) => LoginScreen(initialPhone: phone)),
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

Finder get _phone => find.byType(TextField).at(0);
Finder get _password => find.byType(TextField).at(1);

Future<void> _pressLogin(WidgetTester tester) async {
  await tester.tap(find.byType(PushKeyButton));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('الصفحة بخانات صفحة الحرفي وزرها الأصفر', (tester) async {
    await _pump(tester, _Repo());
    expect(find.byType(RaisedField), findsNWidgets(2));
    expect(find.byType(TextFormField), findsNothing);
    final key = tester.widget<PushKeyButton>(find.byType(PushKeyButton));
    expect(key.label, 'تسجيل الدخول');
    expect(key.yellow, isTrue);
  });

  testWidgets('الصفحة تبدأ بالخانات مباشرة تحت الشريط العلوي', (tester) async {
    await _pump(tester, _Repo());
    final barBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
    expect(tester.getTopLeft(find.text('رقم الهاتف')).dy - barBottom, lessThan(16));
  });

  testWidgets('خانة الهاتف تقبل الأرقام فقط، وكلمة المرور تقبل كل شيء', (tester) async {
    await _pump(tester, _Repo());
    await tester.enterText(_phone, 'abc0770xyz123456789');
    expect(tester.widget<TextField>(_phone).controller!.text, '07701234567');
    await tester.enterText(_password, 'abc123');
    expect(tester.widget<TextField>(_password).controller!.text, 'abc123');
    await tester.pumpAndSettle();
  });

  testWidgets('زر العين يظهر كلمة المرور ويخفيها', (tester) async {
    await _pump(tester, _Repo());
    expect(tester.widget<TextField>(_password).obscureText, isTrue);
    await tester.tap(find.byIcon(Icons.visibility_off_rounded));
    await tester.pump();
    expect(tester.widget<TextField>(_password).obscureText, isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets('الرقم القادم من الشاشة الأولى يظهر، والكتابة تبدأ في كلمة المرور', (tester) async {
    await _pump(tester, _Repo(), phone: '07701234567');
    expect(tester.widget<TextField>(_phone).controller!.text, '07701234567');
    expect(tester.widget<TextField>(_password).focusNode!.hasFocus, isTrue);
  });

  testWidgets('زر الإدخال في لوحة المفاتيح يسجل الدخول', (tester) async {
    await _pump(tester, _Repo(customer: _customer()));
    await tester.enterText(_phone, '07701234567');
    await tester.enterText(_password, 'secret1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('حمرة الخانة تختفي بمجرد الكتابة، وترجع عند الدخول إذا بقي الخطأ', (tester) async {
    await _pump(tester, _Repo());
    await _pressLogin(tester);
    expect(find.text('أدخل رقم الهاتف'), findsOneWidget);
    expect(find.text(_shortPassword), findsOneWidget);

    await tester.enterText(_phone, '0');
    await tester.pump();
    expect(find.text('أدخل رقم الهاتف'), findsNothing);
    expect(find.text(_shortPassword), findsOneWidget);

    await tester.enterText(_password, '1');
    await tester.pump();
    expect(find.text(_shortPassword), findsNothing);

    await _pressLogin(tester);
    expect(find.text('رقم غير صالح (11 رقم يبدأ بـ 07)'), findsOneWidget);
    expect(find.text(_shortPassword), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('الكتابة لا تمسح ما كُتب في الخانة', (tester) async {
    await _pump(tester, _Repo());
    await _pressLogin(tester);
    await tester.enterText(_password, '123');
    await tester.pump();
    expect(tester.widget<TextField>(_password).controller!.text, '123');
  });

  testWidgets('رسالة كلمة المرور الخطأ تختفي بمجرد الكتابة', (tester) async {
    await _pump(tester, _Repo(customer: _customer()));
    await tester.enterText(_phone, '07701234567');
    await tester.enterText(_password, 'wrong12');
    await _pressLogin(tester);
    expect(find.text(_wrongPassword), findsOneWidget);

    await tester.enterText(_password, 'wrong123');
    await tester.pump();
    expect(find.text(_wrongPassword), findsNothing);
  });

  for (final typed in const ['7701234567', '٠٧٧٠١٢٣٤٥٦٧', '0770 123 4567']) {
    testWidgets('الرقم $typed يدخل إلى الحساب نفسه', (tester) async {
      final repo = _Repo(customer: _customer());
      await _pump(tester, repo);
      await tester.enterText(_phone, typed);
      await tester.enterText(_password, 'secret1');
      await _pressLogin(tester);
      expect(repo.asked.single, '07701234567');
      expect(find.byType(LoginScreen), findsNothing);
    });
  }
}
