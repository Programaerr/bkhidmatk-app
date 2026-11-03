import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jaik/core/theme.dart';
import 'package:jaik/data/models.dart';
import 'package:jaik/state/app_state.dart';
import 'package:jaik/ui/auth/push_key.dart';
import 'package:jaik/ui/customer/craftsman_info_screen.dart';
import 'package:jaik/ui/customer/customer_shell.dart';
import 'package:jaik/ui/customer/home_keys.dart';
import 'package:jaik/ui/customer/home_tab.dart';
import 'package:jaik/ui/customer/technicians_tab.dart';

import 'fake_repository.dart';
import 'route_frames.dart';

AppUser _customer() => AppUser(
      id: 1,
      name: 'زبون تجريبي',
      phone: '07701234567',
      passwordHash: '',
      role: 'customer',
      createdAt: DateTime(2026),
    );

Worker _worker(int id, String name, String work, int section) => Worker(
      id: id,
      name: name,
      phone: '',
      specialty: work,
      categoryId: section,
      rating: 4.5,
      bio: 'نبذة $name',
    );

class _Repo extends FakeRepo {
  _Repo({this.failing = false}) : super(customer: _customer());

  final bool failing;
  int workerFetches = 0;

  @override
  Future<List<Category>> listCategories() async => [
        Category(id: 6, name: 'تكييف', icon: 'ac_unit', color: 0xFF000000),
        Category(id: 1, name: 'كهرباء', icon: 'build', color: 0xFF000000),
      ];

  @override
  Future<List<Worker>> listWorkers({int? categoryId, bool onlyAvailable = false}) async {
    workerFetches++;
    if (failing) throw StateError('no network');
    return [
      _worker(1, 'أحمد الجبوري', 'كهربائي منازل', 1),
      _worker(2, 'سيف الدين عباس', 'فني تكييف', 6),
      _worker(3, 'نور الهدى سالم', 'فريق تنظيف', 7),
    ];
  }
}

Future<void> _pumpShell(
  WidgetTester tester, {
  _Repo? repo,
  Size size = const Size(392, 1000),
  double textScale = 1,
  ThemeData? theme,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: AppState(repository: repo ?? _Repo())..user = _customer(),
      child: MaterialApp(
        theme: theme ?? AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Directionality(textDirection: TextDirection.rtl, child: child!),
        ),
        home: const CustomerShell(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 60));
}

Future<void> _openTab(WidgetTester tester) async {
  await tester.tap(find.text('الحرفيين').last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 60));
}

Finder _choice(String label) => find.descendant(
      of: find.byType(TechniciansTab),
      matching: find.widgetWithText(PushKey, label),
    );

Finder get _names => find.descendant(
      of: find.byType(TechniciansTab),
      matching: find.byType(CraftsmanKey),
    );

void main() {
  group('تبويب الحرفيين', () {
    testWidgets('اسم التبويب الحرفيين بدل الفنيين، والعنوان كل الحرفيين', (tester) async {
      await _pumpShell(tester);
      expect(find.text('الخدمات'), findsNothing);
      expect(find.text('الفنيين'), findsNothing);
      await _openTab(tester);
      expect(find.text('كل الحرفيين'), findsOneWidget);
      expect(find.text('كل الفنيين'), findsNothing);
      expect(find.text('كل الخدمات'), findsNothing);
      expect(find.text('ابحث عن حرفي'), findsOneWidget);
    });

    testWidgets('يعرض الحرفيين، والضغط على الحرفي يفتح معلوماته', (tester) async {
      await _pumpShell(tester);
      await _openTab(tester);
      expect(_names, findsNWidgets(3));
      await tester.tap(_names.first);
      await tester.pump();
      await pumpRouteFrames(tester);
      expect(find.byType(CraftsmanInfoScreen), findsOneWidget);
    });

    testWidgets('البحث والاختيارات والحرفيون كلها من نظام الأزرار نفسه', (tester) async {
      await _pumpShell(tester);
      await _openTab(tester);
      final search = find.ancestor(of: find.byType(TextField), matching: find.byType(PushKey));
      expect(search, findsOneWidget);

      // خانة البحث بلا إطار خانات التطبيق، فالزر نفسه هو الخانة.
      final decoration = tester.widget<TextField>(find.byType(TextField)).decoration!;
      expect(decoration.enabledBorder, InputBorder.none);
      expect(decoration.focusedBorder, InputBorder.none);
      expect(decoration.filled, isFalse);

      expect(_choice('الكل'), findsOneWidget);
      expect(tester.widget<PushKey>(_choice('الكل')).lemon, isTrue);
      expect(tester.widget<PushKey>(_choice('كهرباء')).lemon, isFalse);
      expect(
        tester.widget<PushKey>(find.descendant(of: _names.first, matching: find.byType(PushKey))).lemon,
        isTrue,
      );
    });

    testWidgets('الاختيارات في صف واحد، تبدأ بالكل من اليمين وبعرض التصميم', (tester) async {
      await _pumpShell(tester);
      await _openTab(tester);
      final all = tester.getRect(_choice('الكل'));
      final next = tester.getRect(_choice('سبالت'));
      expect(all.left, greaterThan(next.left));
      expect(all.top, closeTo(next.top, .01));
      expect(all.width, greaterThanOrEqualTo(68));
    });

    testWidgets('الاختيار يعرض حرفيي نوع الشغل، حتى القسم الذي اسمه قديم في السيرفر', (tester) async {
      await _pumpShell(tester);
      await _openTab(tester);

      await tester.tap(_choice('سبالت'));
      await tester.pump();
      expect(tester.widget<PushKey>(_choice('سبالت')).lemon, isTrue);
      expect(tester.widget<PushKey>(_choice('الكل')).lemon, isFalse);
      expect(_names, findsOneWidget);
      expect(
        find.descendant(of: find.byType(TechniciansTab), matching: find.text('سيف الدين عباس')),
        findsOneWidget,
      );

      await tester.tap(_choice('الكل'));
      await tester.pump();
      expect(_names, findsNWidgets(3));
    });

    testWidgets('البحث بالاسم وبنوع الشغل، ولا يهم الفرق بين أ وا', (tester) async {
      await _pumpShell(tester);
      await _openTab(tester);
      final field = find.byType(TextField);

      await tester.enterText(field, 'احمد');
      await tester.pump();
      expect(_names, findsOneWidget);

      await tester.enterText(field, 'تكييف');
      await tester.pump();
      expect(_names, findsOneWidget);

      await tester.enterText(field, 'الهدي');
      await tester.pump();
      expect(_names, findsOneWidget);
    });

    testWidgets('لا طلب من السيرفر مع كل حرف، وزر المسح يرجع الكل', (tester) async {
      final repo = _Repo();
      await _pumpShell(tester, repo: repo);
      await _openTab(tester);
      final fetches = repo.workerFetches;

      await tester.enterText(find.byType(TextField), 'لا يوجد');
      await tester.pump();
      expect(repo.workerFetches, fetches);
      expect(_names, findsNothing);
      expect(find.text('لا يوجد حرفيون مطابقون'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(_names, findsNWidgets(3));
    });

    testWidgets('البحث يعمل مع الاختيار معاً', (tester) async {
      await _pumpShell(tester);
      await _openTab(tester);
      await tester.tap(_choice('كهرباء'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'سيف');
      await tester.pump();
      expect(_names, findsNothing);
      await tester.enterText(find.byType(TextField), 'احمد');
      await tester.pump();
      expect(_names, findsOneWidget);
    });

    testWidgets('يفتح فوراً مما جلبته الرئيسية، بلا طلب جديد من السيرفر', (tester) async {
      final repo = _Repo();
      await _pumpShell(tester, repo: repo);
      final fetches = repo.workerFetches;
      await tester.tap(find.text('الحرفيين').last);
      await tester.pump();
      expect(_names, findsNWidgets(3));
      expect(repo.workerFetches, fetches);
    });

    testWidgets('إذا لم تصل بيانات الرئيسية بعد يجلبها بنفسه', (tester) async {
      final repo = _Repo();
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: AppState(repository: repo)..user = _customer(),
          child: const MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(body: TechniciansTab()),
            ),
          ),
        ),
      );
      expect(repo.workerFetches, 1);
      expect(find.byType(CraftsmanKey), findsNWidgets(6));
      await tester.pump();
      expect(find.byType(CraftsmanKey), findsNWidgets(3));
    });

    testWidgets('إذا فشل الجلب تظهر رسالة، ولا تبقى الأزرار الفارغة', (tester) async {
      final repo = _Repo(failing: true);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: AppState(repository: repo)..user = _customer(),
          child: const MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(body: TechniciansTab()),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('تعذّر جلب الحرفيين'), findsOneWidget);
      expect(find.byType(CraftsmanKey), findsNothing);
    });

    group('من أقسام الرئيسية', () {
      Finder circle(String label) => find.byWidgetPredicate(
            (widget) => widget is PushKeyCircle && widget.label == label,
          );

      testWidgets('الضغط على قسم يفتح التبويب على حرفييه والزر المختار ظاهر في الشاشة', (tester) async {
        await _pumpShell(tester);
        await tester.tap(circle('كهرباء'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.byType(TechniciansTab), findsOneWidget);
        expect(tester.widget<PushKey>(_choice('كهرباء')).lemon, isTrue);
        expect(_names, findsOneWidget);
        expect(
          find.descendant(of: find.byType(TechniciansTab), matching: find.text('أحمد الجبوري')),
          findsOneWidget,
        );
        final chip = tester.getRect(_choice('كهرباء'));
        expect(chip.left, greaterThanOrEqualTo(0));
        expect(chip.right, lessThanOrEqualTo(392));
      });

      testWidgets('القسم البعيد في الشريط يصل إليه الشريط وحده', (tester) async {
        await _pumpShell(tester);
        await tester.tap(circle('نجار'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        final chip = tester.getRect(_choice('نجار'));
        expect(chip.left, greaterThanOrEqualTo(0));
        expect(chip.right, lessThanOrEqualTo(392));
      });

      testWidgets('الضغط على القسم نفسه مرة ثانية يرجع إليه، ويمسح البحث القديم', (tester) async {
        await _pumpShell(tester);
        await tester.tap(circle('كهرباء'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));

        await tester.tap(_choice('الكل'));
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'لا يوجد');
        await tester.pump();
        expect(_names, findsNothing);

        await tester.tap(find.text('الرئيسية').last);
        await tester.pump();
        await tester.tap(circle('كهرباء'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.widget<PushKey>(_choice('كهرباء')).lemon, isTrue);
        expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
        expect(_names, findsOneWidget);
      });

      testWidgets('زر رجوع الهاتف يرجع من التبويب إلى الرئيسية', (tester) async {
        await _pumpShell(tester);
        await tester.tap(circle('كهرباء'));
        await tester.pump();
        expect(TickerMode.valuesOf(tester.element(find.byType(TechniciansTab))).enabled, isTrue);

        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(
          TickerMode.valuesOf(tester.element(find.byType(TechniciansTab, skipOffstage: false))).enabled,
          isFalse,
        );
      });
    });

    testWidgets('لوحة المفاتيح لا تبقى مفتوحة عند الانتقال إلى تبويب آخر', (tester) async {
      await _pumpShell(tester);
      await _openTab(tester);
      await tester.showKeyboard(find.byType(TextField));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.tap(find.text('الرئيسية').last);
      await tester.pump();
      expect(tester.testTextInput.isVisible, isFalse);
    });

    for (final (size, scale) in const [
      (Size(320, 568), 1.3),
      (Size(360, 640), 1.0),
      (Size(392, 825), 2.0),
      (Size(412, 915), 1.0),
      (Size(825, 392), 1.0),
      (Size(1280, 800), 1.0),
    ]) {
      testWidgets('لا شيء يفيض على ${size.width.toInt()}x${size.height.toInt()} @${scale}x', (tester) async {
        await _pumpShell(tester, size: size, textScale: scale);
        await _openTab(tester);
        expect(tester.takeException(), isNull);

        await tester.enterText(find.byType(TextField), 'لا يوجد');
        await tester.pump();
        expect(tester.takeException(), isNull);

        tester.view.viewInsets = const FakeViewPadding(bottom: 250);
        addTearDown(tester.view.resetViewInsets);
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('آخر صف في الرئيسية والحرفيين يبقى فوق شريط التنقل الزجاجي', (tester) async {
      await _pumpShell(tester, size: const Size(392, 700));
      await tester.pump(const Duration(milliseconds: 500));
      final bar = tester.getRect(find.byKey(const ValueKey('glass-navigation-bar')));

      Future<void> expectClear(Type tab) async {
        final list = find.descendant(of: find.byType(tab), matching: find.byType(Scrollable)).first;
        await tester.drag(list, const Offset(0, -3000));
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        final last = find.descendant(of: find.byType(tab), matching: find.byType(CraftsmanKey)).last;
        expect(tester.getRect(last).bottom, lessThanOrEqualTo(bar.top));
      }

      await expectClear(HomeTab);
      await _openTab(tester);
      await expectClear(TechniciansTab);
    });

    testWidgets('يعمل في الوضع الليلي', (tester) async {
      await _pumpShell(tester, theme: AppTheme.dark());
      await _openTab(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('كل الحرفيين'), findsOneWidget);
    });
  });
}
