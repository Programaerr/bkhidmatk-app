import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jaik/core/theme.dart';
import 'package:jaik/state/app_state.dart';
import 'package:jaik/ui/auth/craftsman_screen.dart';
import 'package:jaik/ui/auth/login_screen.dart';
import 'package:jaik/ui/auth/push_key.dart';
import 'package:jaik/ui/auth/raised_field.dart';
import 'package:jaik/ui/auth/register_screen.dart';

import 'fake_repository.dart';

Future<void> _pump(WidgetTester tester, Widget screen, {ThemeData? theme}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view
    ..physicalSize = const Size(392, 825)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: AppState(repository: FakeRepo()),
      child: MaterialApp(
        theme: theme ?? AppTheme.light(),
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
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

Finder _inBar(Finder finder) => find.descendant(of: find.byType(AppBar), matching: finder);

Finder get _backKey => _inBar(find.byType(PushKey));

void main() {
  const pages = <String, Widget>{
    'إنشاء حساب': RegisterScreen(),
    'التقديم كحرفي': CraftsmanScreen(),
    'تسجيل الدخول': LoginScreen(),
  };

  pages.forEach((title, screen) {
    testWidgets('زر الرجوع في «$title» سهم فقط، بلا اسم يظهر عند الوقوف عليه', (tester) async {
      await _pump(tester, screen);
      expect(find.descendant(of: _backKey, matching: find.byIcon(Icons.arrow_back)), findsOneWidget);
      expect(find.descendant(of: _backKey, matching: find.byType(Text)), findsNothing);
      expect(_inBar(find.byType(Tooltip)), findsNothing);
      expect(_inBar(find.byType(BackButton)), findsNothing);
    });

    testWidgets('زر الرجوع في «$title» بارتفاع أزرار الصفحة ولونها، وعلى حافة خاناتها', (tester) async {
      await _pump(tester, screen);
      final pageKey = tester.widget<PushKey>(
        find.descendant(of: find.byType(PushKeyButton).first, matching: find.byType(PushKey)),
      );
      final backKey = tester.widget<PushKey>(_backKey);
      expect(backKey.unit, pageKey.unit);
      expect(backKey.faceHeight, pageKey.faceHeight);
      expect(backKey.yellow, isFalse);

      final key = tester.getRect(_backKey);
      expect(key.right, closeTo(tester.getRect(find.byType(RaisedField).first).right, .5));
      expect(tester.getRect(_inBar(find.text(title))).right, lessThan(key.left));
      expect(key.top, greaterThanOrEqualTo(tester.getRect(find.byType(AppBar)).top));
      expect(key.bottom, lessThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom));
    });

    testWidgets('زر الرجوع في «$title» يرجع إلى الصفحة السابقة', (tester) async {
      await _pump(tester, screen);
      await tester.tap(_backKey);
      await tester.pumpAndSettle();
      expect(find.text('الشاشة الأولى'), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('زر الرجوع في «$title» بألوان الليل وسهمه فاتح', (tester) async {
      await _pump(tester, screen, theme: AppTheme.dark());
      expect(tester.widget<PushKey>(_backKey).night.value, 1);
      final arrow = tester.widget<Icon>(find.descendant(of: _backKey, matching: find.byType(Icon)));
      expect(arrow.color, const Color(0xFFF4F4EE));
    });
  });
}
