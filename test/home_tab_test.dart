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
import 'package:jaik/ui/customer/home_lists_screens.dart';
import 'package:jaik/ui/customer/messages_screen.dart';
import 'package:jaik/ui/customer/notifications_screen.dart';
import 'package:jaik/ui/customer/profile_tab.dart';
import 'package:jaik/ui/customer/services_tab.dart';
import 'package:jaik/ui/customer/workers_scene.dart';
import 'package:jaik/ui/widgets/quick_route.dart';

import 'fake_repository.dart';
import 'route_frames.dart';

const _sectionNames = [
  'سبالت', 'كهرباء', 'سباكة', 'صباغ', 'التنظيف', 'اجهزة المنزل', 'مجاري', 'نجار', 'حداد',
  'ديكورات', 'تركيب كامرات', 'حدائق', 'طاقة شمسية', 'عامل', 'ابواب و شبابيك', 'نقل الاثاث',
  'شد و تركيب الاثاث', 'غسيل سيارات',
];

AppUser _customer() => AppUser(
      id: 1,
      name: 'زبون تجريبي',
      phone: '07701234567',
      passwordHash: '',
      role: 'customer',
      createdAt: DateTime(2026),
    );

Worker _worker(int i) => Worker(
      id: i,
      name: 'حرفي $i',
      phone: '',
      specialty: 'شغل $i',
      rating: 4.5,
      jobsDone: 10 + i,
      bio: 'نبذة الحرفي $i',
    );

class _HomeRepo extends FakeRepo {
  _HomeRepo({this.craftsmen = 8, this.unread = 0}) : super(customer: _customer());

  final int craftsmen;
  final int unread;
  bool? askedOnlyAvailable;
  int sectionFetches = 0;
  int workerFetches = 0;

  @override
  Future<List<Category>> listCategories() async {
    sectionFetches++;
    return [
      for (final (i, name) in _sectionNames.indexed)
        Category(id: i + 1, name: name, icon: 'build', color: 0xFF000000, sortOrder: i),
    ];
  }

  @override
  Future<List<Worker>> listWorkers({int? categoryId, bool onlyAvailable = false}) async {
    workerFetches++;
    askedOnlyAvailable = onlyAvailable;
    return [for (var i = 1; i <= craftsmen; i++) _worker(i)];
  }

  @override
  Future<int> unreadForCustomer(int customerId) async => unread;
}

/// ما في السيرفر اليوم: الأقسام الثمانية القديمة.
class _OldServerRepo extends _HomeRepo {
  @override
  Future<List<Category>> listCategories() async => [
        for (final (id, name) in const [
          (8, 'نجارة'),
          (7, 'تنظيف'),
          (6, 'تكييف'),
          (5, 'سباكة'),
          (4, 'ديكورات'),
          (3, 'صباغة'),
          (2, 'تصليح غسالات'),
          (1, 'كهرباء'),
        ])
          Category(id: id, name: name, icon: 'build', color: 0xFF000000),
      ];
}

Future<void> _pumpHome(
  WidgetTester tester, {
  _HomeRepo? repo,
  Size size = const Size(392, 1100),
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
      value: AppState(repository: repo ?? _HomeRepo())..user = _customer(),
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

Finder _circle(String label) =>
    find.byWidgetPredicate((widget) => widget is PushKeyCircle && widget.label == label);

Future<void> _tapAndOpen(WidgetTester tester, Finder target) async {
  await tester.tap(target);
  await tester.pump();
  await pumpRouteFrames(tester);
}

void main() {
  group('الصفحة الرئيسية', () {
    testWidgets('تعرض الاسم وثمانية أقسام بالترتيب', (tester) async {
      await _pumpHome(tester);
      expect(find.text('زبون تجريبي'), findsOneWidget);
      expect(find.text('الأقسام'), findsOneWidget);
      expect(find.text('حرفي بالقرب منك'), findsOneWidget);
      expect(find.text('عرض الكل'), findsNWidgets(2));
      expect(find.byType(WorkersScene), findsOneWidget);

      // سهم «عرض الكل» على يسار الكلام ويتجه إلى اليسار.
      final arrow = find.byIcon(Icons.arrow_back);
      expect(arrow, findsNWidgets(2));
      expect(tester.widget<Icon>(arrow.first).textDirection, TextDirection.ltr);
      expect(
        tester.getCenter(arrow.first).dx,
        lessThan(tester.getCenter(find.text('عرض الكل').first).dx),
      );

      // «عرض الكل» وسهمه في وسط الدائرة اليسرى، و«الأقسام» في وسط الدائرة اليمنى.
      final allMiddle = (tester.getTopLeft(arrow.first).dx +
              tester.getTopRight(find.text('عرض الكل').first).dx) /
          2;
      expect(allMiddle, closeTo(tester.getCenter(_circle(_sectionNames[3])).dx, 1));
      expect(
        tester.getCenter(find.text('الأقسام')).dx,
        closeTo(tester.getCenter(_circle(_sectionNames[0])).dx, 1),
      );

      for (final name in _sectionNames.take(8)) {
        expect(_circle(name), findsOneWidget, reason: name);
      }
      expect(_circle(_sectionNames[8]), findsNothing);

      // الأول في أقصى اليمين، والخامس تحته.
      final first = tester.getCenter(_circle(_sectionNames[0]));
      final second = tester.getCenter(_circle(_sectionNames[1]));
      final fifth = tester.getCenter(_circle(_sectionNames[4]));
      expect(first.dx, greaterThan(second.dx));
      expect(fifth.dx, closeTo(first.dx, .01));
      expect(fifth.dy, greaterThan(first.dy));
    });

    testWidgets('تعرض ستة حرفيين متاحين بالاسم ونوع الشغل والتقييم', (tester) async {
      final repo = _HomeRepo();
      await _pumpHome(tester, repo: repo);
      expect(repo.askedOnlyAvailable, isTrue);
      expect(find.byType(CraftsmanKey), findsNWidgets(6));
      expect(find.text('حرفي 1'), findsOneWidget);
      expect(find.text('شغل 1'), findsOneWidget);
      expect(find.text('4.5'), findsNWidgets(6));
      expect(find.text('حرفي 7'), findsNothing);

      // الاسم فوق نوع الشغل، والتقييم في الجهة البعيدة عن الدائرة وتحت الاسم.
      final name = tester.getCenter(find.text('حرفي 1'));
      final work = tester.getCenter(find.text('شغل 1'));
      final rating = tester.getCenter(find.text('4.5').first);
      expect(name.dy, lessThan(work.dy));
      expect(rating.dx, lessThan(work.dx));
      expect(rating.dy, greaterThan(name.dy));
    });

    testWidgets('كل الأزرار بشكل أزرار الدخول: دوائر، والحرفي بالأصفر', (tester) async {
      await _pumpHome(tester);
      for (final label in ['الملف الشخصي', 'الرسائل', 'الإشعارات', _sectionNames[0]]) {
        final key = tester.widget<PushKey>(
          find.descendant(of: _circle(label), matching: find.byType(PushKey)),
        );
        expect(key.round, isTrue, reason: label);
      }
      final craftsman = tester.widget<PushKey>(
        find.descendant(of: find.byType(CraftsmanKey).first, matching: find.byType(PushKey)),
      );
      expect(craftsman.lemon, isTrue);
      expect(craftsman.round, isFalse);
    });

    testWidgets('الاسم في وسط دائرة الملف الشخصي وبعيد عنها', (tester) async {
      await _pumpHome(tester);
      final circle = tester.getRect(_circle('الملف الشخصي'));
      final name = tester.getRect(find.text('زبون تجريبي'));
      expect(name.center.dy, closeTo(circle.center.dy, .5));
      expect(circle.left - name.right, closeTo(10, .5));
    });

    testWidgets('الزران الصغيران مساحة لمسهما كافية ولا تتداخلان', (tester) async {
      await _pumpHome(tester);
      final messages = tester.getRect(_circle('الرسائل'));
      final notifications = tester.getRect(_circle('الإشعارات'));
      expect(messages.width, greaterThanOrEqualTo(48));
      expect(messages.height, greaterThanOrEqualTo(47));
      expect(messages.overlaps(notifications), isFalse);
    });

    testWidgets('الأزرار المتشابهة تتشارك صورتها، وتبقى صحيحة بعد غلق صفحة فوقها', (tester) async {
      await _pumpHome(tester);
      await _tapAndOpen(tester, find.text('عرض الكل').first);
      await tester.pump();
      Navigator.of(tester.element(find.byType(AllSectionsScreen))).pop();
      await tester.pump();
      await pumpRouteFrames(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(_circle(_sectionNames[0]), findsOneWidget);
    });

    testWidgets('زر الرسائل قبل زر الإشعارات من اليمين، وعليه عدد غير المقروء', (tester) async {
      await _pumpHome(tester, repo: _HomeRepo(unread: 3));
      expect(
        tester.getCenter(_circle('الرسائل')).dx,
        greaterThan(tester.getCenter(_circle('الإشعارات')).dx),
      );
      expect(
        find.descendant(of: _circle('الرسائل'), matching: find.text('3')),
        findsOneWidget,
      );
    });

    testWidgets('دائرة الملف الشخصي تفتح تبويب الحساب', (tester) async {
      await _pumpHome(tester);
      await tester.tap(_circle('الملف الشخصي'));
      await tester.pump();
      expect(find.byType(ProfileTab), findsOneWidget);
    });

    testWidgets('زرا الرسائل والإشعارات يفتحان صفحتيهما', (tester) async {
      await _pumpHome(tester);
      await _tapAndOpen(tester, _circle('الرسائل'));
      expect(find.byType(MessagesScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(MessagesScreen))).pop();
      await tester.pump();
      await pumpRouteFrames(tester);

      await _tapAndOpen(tester, _circle('الإشعارات'));
      expect(find.byType(NotificationsScreen), findsOneWidget);
      await tester.pump();
      expect(find.text('لا توجد إشعارات'), findsOneWidget);
    });

    testWidgets('زر القسم يفتح خدماته', (tester) async {
      await _pumpHome(tester);
      await _tapAndOpen(tester, _circle(_sectionNames[1]));
      expect(tester.widget<ServicesPage>(find.byType(ServicesPage)).initialCategoryId, 2);
    });

    testWidgets('زر الحرفي يفتح معلوماته', (tester) async {
      await _pumpHome(tester);
      await _tapAndOpen(tester, find.byType(CraftsmanKey).first);
      expect(find.byType(CraftsmanInfoScreen), findsOneWidget);
      expect(find.text('حرفي 1'), findsWidgets);
      expect(find.text('نبذة الحرفي 1'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);
    });

    testWidgets('عرض الكل يفتح كل الأقسام وكل الحرفيين', (tester) async {
      await _pumpHome(tester);
      await _tapAndOpen(tester, find.text('عرض الكل').first);
      expect(find.byType(AllSectionsScreen), findsOneWidget);
      await tester.pump();
      for (final name in _sectionNames) {
        expect(_circle(name), findsWidgets, reason: name);
      }
      Navigator.of(tester.element(find.byType(AllSectionsScreen))).pop();
      await tester.pump();
      await pumpRouteFrames(tester);

      await _tapAndOpen(tester, find.text('عرض الكل').last);
      expect(find.byType(AllCraftsmenScreen), findsOneWidget);
      await tester.pump();
      expect(find.text('حرفي 8'), findsOneWidget);
    });

    testWidgets('عرض الكل يظهر فوراً مما جلبته الصفحة، بلا طلب جديد من السيرفر', (tester) async {
      final repo = _HomeRepo();
      await _pumpHome(tester, repo: repo);
      final sections = repo.sectionFetches;

      // الإطار الأول بعد الفتح مخفي عند كل انتقال، والمحتوى كامل في أول إطار ظاهر.
      await tester.tap(find.text('عرض الكل').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(_circle(_sectionNames.last), findsOneWidget);
      await pumpRouteFrames(tester);
      expect(repo.sectionFetches, sections);
      Navigator.of(tester.element(find.byType(AllSectionsScreen))).pop();
      await tester.pump();
      await pumpRouteFrames(tester);

      // بعد الرجوع تحدّث الصفحة الرئيسية بياناتها، والعدّ يبدأ بعدها.
      await tester.pump(const Duration(milliseconds: 500));
      final workers = repo.workerFetches;

      await tester.tap(find.text('عرض الكل').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('حرفي 8'), findsOneWidget);
      await pumpRouteFrames(tester);
      expect(repo.workerFetches, workers);
    });

    testWidgets('إذا لم تصل البيانات بعد تجلبها صفحة عرض الكل بنفسها', (tester) async {
      final repo = _HomeRepo();
      await _pumpHome(tester, repo: repo);
      Navigator.of(tester.element(find.byType(CraftsmanKey).first)).push(
        QuickRoute<void>(builder: (_) => const AllSectionsScreen()),
      );
      await tester.pump();
      final sections = repo.sectionFetches;
      await tester.pump();
      await pumpRouteFrames(tester);
      expect(sections, greaterThanOrEqualTo(2));
      expect(_circle(_sectionNames.last), findsOneWidget);
    });

    testWidgets('الرجوع من صفحة يعيد التحميل مرة واحدة بعد انتهاء الانتقال', (tester) async {
      final repo = _HomeRepo();
      await _pumpHome(tester, repo: repo);
      await _tapAndOpen(tester, _circle('الإشعارات'));
      await tester.pump();
      final before = repo.sectionFetches;

      Navigator.of(tester.element(find.byType(NotificationsScreen))).pop();
      await tester.pump();
      await pumpRouteFrames(tester);
      expect(repo.sectionFetches, before);

      await tester.pump(const Duration(milliseconds: 400));
      expect(repo.sectionFetches, before + 1);
    });

    testWidgets('السيرفر بأقسامه الثمانية القديمة: تظهر الأقسام كلها، والجديد منها يفتح فارغاً', (tester) async {
      await _pumpHome(tester, repo: _OldServerRepo());
      expect(_circle('سبالت'), findsOneWidget);
      expect(find.text('تكييف'), findsNothing);

      await _tapAndOpen(tester, find.text('عرض الكل').first);
      await tester.pump();
      for (final name in _sectionNames) {
        expect(_circle(name), findsWidgets, reason: name);
      }

      // القسم القديم تحت اسمه الجديد يفتح خدماته برقمه.
      await _tapAndOpen(tester, _circle('سبالت').last);
      expect(tester.widget<ServicesPage>(find.byType(ServicesPage)).initialCategoryId, 6);
      Navigator.of(tester.element(find.byType(ServicesPage))).pop();
      await tester.pump();
      await pumpRouteFrames(tester);

      // القسم الجديد لا يعرض كل الخدمات، بل صفحة فارغة.
      await _tapAndOpen(tester, _circle('حداد').last);
      final page = tester.widget<ServicesPage>(find.byType(ServicesPage));
      expect(page.initialCategoryId, isNotNull);
      expect(page.initialCategoryId!, isNegative);
      await tester.pump();
      expect(find.text('لا توجد خدمات مطابقة'), findsOneWidget);
    });

    testWidgets('بلا حرفيين متاحين تظهر رسالة بدل الأزرار', (tester) async {
      await _pumpHome(tester, repo: _HomeRepo(craftsmen: 0));
      expect(find.byType(CraftsmanKey), findsNothing);
      expect(find.text('لا يوجد حرفيون متاحون الآن'), findsOneWidget);
    });

    testWidgets('السحب فوق الزر لتحريك الصفحة لا يبقيه منضغطاً ولا يفتحه', (tester) async {
      await _pumpHome(tester);
      final key = _circle(_sectionNames[0]);
      bool pressed() =>
          tester
              .widget<TweenAnimationBuilder<double>>(
                find.descendant(of: key, matching: find.byType(TweenAnimationBuilder<double>)),
              )
              .tween
              .end ==
          1;

      final gesture = await tester.startGesture(tester.getCenter(key));
      await tester.pump();
      expect(pressed(), isTrue);

      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      expect(pressed(), isFalse);

      await gesture.up();
      await tester.pump();
      expect(find.byType(ServicesPage), findsNothing);
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
        await _pumpHome(tester, size: size, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(find.byType(CraftsmanKey), findsNWidgets(6));

        Navigator.of(tester.element(find.byType(CraftsmanKey).first)).push(
          QuickRoute<void>(builder: (_) => CraftsmanInfoScreen(worker: _worker(1))),
        );
        await tester.pump();
        await pumpRouteFrames(tester);
        expect(find.byType(CraftsmanInfoScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('تعمل في الوضع الليلي', (tester) async {
      await _pumpHome(tester, theme: AppTheme.dark());
      expect(tester.takeException(), isNull);
      expect(find.text('الأقسام'), findsOneWidget);
    });
  });

  group('حركة العاملين', () {
    test('العاملان يتحركان باستمرار', () {
      const start = WorkersPose(0);
      const later = WorkersPose(.65);
      expect(later.upperArm, isNot(closeTo(start.upperArm, .001)));
      expect(later.lowerArm, isNot(closeTo(start.lowerArm, .001)));
      expect(later.reachingArm, isNot(closeTo(start.reachingArm, .001)));
      expect(later.holdingArm, isNot(closeTo(start.holdingArm, .001)));
    });

    test('يدا العامل الواقف تتحركان بعكس بعضهما على العجلة', () {
      for (final time in [.3, .65, 1.1, 1.9, 2.4]) {
        final pose = WorkersPose(time);
        expect(pose.upperArm * pose.lowerArm, lessThanOrEqualTo(0), reason: '$time');
      }
    });

    test('الحركة صغيرة حتى تبقى اليدان على العجلة والعداد', () {
      for (var time = 0.0; time < 20; time += .05) {
        final pose = WorkersPose(time);
        expect(pose.upperArm.abs(), lessThanOrEqualTo(.06));
        expect(pose.lowerArm.abs(), lessThanOrEqualTo(.06));
        expect(pose.reachingArm.abs(), lessThanOrEqualTo(.03));
        expect(pose.holdingArm.abs(), lessThanOrEqualTo(.03));
        expect(pose.standingLean.abs(), lessThanOrEqualTo(.01));
        expect(pose.kneelingLean.abs(), lessThanOrEqualTo(.01));
      }
    });
  });
}
