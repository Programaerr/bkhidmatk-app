import 'dart:math' as math;

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
import 'package:jaik/ui/customer/technicians_tab.dart';
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
  Future<List<Worker>> listWorkers({int? categoryId, bool onlyAvailable = false}) async {
    await super.listWorkers(categoryId: categoryId, onlyAvailable: onlyAvailable);
    return [
      Worker(id: 6, name: 'حرفي 6', phone: '', specialty: 'فني مكيفات', categoryId: 6, rating: 4.5),
      Worker(id: 1, name: 'حرفي 1', phone: '', specialty: 'كهرباء', categoryId: 1, rating: 4.5),
    ];
  }

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

    testWidgets('زر القسم يفتح تبويب الفنيين على نوع الشغل نفسه، لا الخدمات', (tester) async {
      await _pumpHome(tester);
      await tester.tap(_circle(_sectionNames[1]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(TechniciansTab), findsOneWidget);
      expect(find.text('كل الخدمات'), findsNothing);
      final chosen = tester.widget<PushKey>(find.descendant(
        of: find.byType(TechniciansTab),
        matching: find.widgetWithText(PushKey, _sectionNames[1]),
      ));
      expect(chosen.lemon, isTrue);
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

      // الضغط يرجع من الصفحة إلى تبويب الفنيين، والقسم القديم يجد حرفييه برقمه.
      await _tapAndOpen(tester, _circle('سبالت').last);
      expect(find.byType(AllSectionsScreen), findsNothing);
      Finder inTab(Type type) =>
          find.descendant(of: find.byType(TechniciansTab), matching: find.byType(type));
      expect(inTab(CraftsmanKey), findsNWidgets(1));
      expect(
        find.descendant(of: find.byType(TechniciansTab), matching: find.text('حرفي 6')),
        findsOneWidget,
      );

      // القسم الذي ليس له حرفيون لا يعرض كل الحرفيين، بل رسالة.
      await tester.tap(find.text('الرئيسية').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await _tapAndOpen(tester, find.text('عرض الكل').first);
      await tester.pump();
      await _tapAndOpen(tester, _circle('حداد').last);
      expect(inTab(CraftsmanKey), findsNothing);
      expect(find.text('لا يوجد حرفيون مطابقون'), findsOneWidget);
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
      expect(find.byType(TechniciansTab), findsNothing);
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
    void expectAsDrawn(WorkerFace face) {
      for (final value in [
        face.browLift, face.browKnit, face.squint, face.happy, face.smile, face.open, face.teeth,
        face.grin, face.tongue, face.sweat,
      ]) {
        expect(value, closeTo(0, 1e-9));
      }
      expect(face.look, Offset.zero);
    }

    test('يبدآن كما في الرسم، فيبقى الرسم نفسه حين تُطفأ الحركة', () {
      const pose = WorkersPose(0);
      for (final value in [
        pose.wheelTurn, pose.upperArm, pose.lowerArm, pose.standingLean, pose.standingHead,
        pose.standingNeedle, pose.kneelingLean, pose.kneelingHead, pose.reachingArm,
        pose.holdingArm, pose.meterTilt, pose.smallNeedle, pose.tallNeedle,
      ]) {
        expect(value, closeTo(0, 1e-9));
      }
      expectAsDrawn(pose.standingFace);
      expectAsDrawn(pose.kneelingFace);
    });

    test('لا يقفان: في كل لحظة يتحرك فيهما شيء', () {
      for (var time = 0.0; time < 18; time += .3) {
        final now = WorkersPose(time), next = WorkersPose(time + .3);
        final moved = [
          (now.standingLean, next.standingLean),
          (now.kneelingLean, next.kneelingLean),
          (now.holdingArm, next.holdingArm),
          (now.standingNeedle, next.standingNeedle),
        ].any((pair) => (pair.$1 - pair.$2).abs() > 1e-4);
        expect(moved, isTrue, reason: '$time');
      }
    });

    test('العجلة تدور مع كل دفعة ولا ترجع أبداً', () {
      var last = const WorkersPose(0).wheelTurn;
      for (var time = .02; time < 30; time += .02) {
        final turn = WorkersPose(time).wheelTurn;
        expect(turn, lessThanOrEqualTo(last + 1e-9), reason: '$time');
        last = turn;
      }
      // في كل دورة ثلاث دفعات، وكل دفعة تديرها ضلعاً ونصفاً من أضلاعها التسعة: نصف لفة كاملة.
      expect(const WorkersPose(WorkersPose.standingCycle).wheelTurn, closeTo(-math.pi, 1e-9));
    });

    test('العجلة لا تدور إلا ويداه تدفعانها', () {
      for (var time = 0.0; time < 18; time += .05) {
        final now = WorkersPose(time), next = WorkersPose(time + .05);
        if ((next.wheelTurn - now.wheelTurn).abs() > 1e-6) {
          expect(math.max(now.upperArm, next.upperArm), greaterThan(0), reason: '$time');
          expect(math.min(now.lowerArm, next.lowerArm), lessThan(0), reason: '$time');
        }
      }
    });

    test('مؤشر عداده ينزل، وكل دفعة ترفعه، ثم يرجع إلى علامته', () {
      final needle = [for (final time in [2.3, 3.7, 5.1, 7.6]) WorkersPose(time).standingNeedle];
      expect(needle.first, lessThan(-.9));
      expect(needle[1], greaterThan(needle[0] + .25));
      expect(needle[2], greaterThan(needle[1] + .25));
      expect(needle.last.abs(), lessThan(.06));
    });

    test('وجه العامل الواقف يتغير مع الشغل بملامح تُرى على الهاتف', () {
      // يتفاجأ: عينان واسعتان وحاجبان عاليان وفم مفتوح.
      final worried = const WorkersPose(1.9).standingFace;
      expect(worried.browLift, greaterThan(1));
      expect(worried.squint, lessThan(-.3));
      expect(worried.open, greaterThan(.8));

      // يشد: عينان مغمضتان وأسنان مضغوطة وحاجبان معقودان، وفي الدفعة الأخيرة يعرق.
      final straining = const WorkersPose(2.85).standingFace;
      expect(straining.squint, greaterThan(.8));
      expect(straining.teeth, greaterThan(.8));
      expect(straining.browKnit, greaterThan(.3));
      expect(const WorkersPose(5.8).standingFace.sweat, greaterThan(.8));

      // يفرح: عينان كقوسين وضحكة واسعة.
      final pleased = const WorkersPose(7.8).standingFace;
      expect(pleased.happy, greaterThan(.8));
      expect(pleased.grin, greaterThan(.8));
      expect(pleased.browLift, greaterThan(.5));
    });

    test('العامل الجالس يلف العداد الصغير خطوة خطوة، والكبير يتبعه، ثم يرضى', () {
      final small = [for (final time in [2.15, 2.75, 3.45, 4.15]) WorkersPose(time).smallNeedle];
      for (var i = 1; i < small.length; i++) {
        expect(small[i], greaterThan(small[i - 1] + .1), reason: '$i');
      }
      expect(const WorkersPose(2).tallNeedle, lessThan(-.7));
      expect(const WorkersPose(5.5).tallNeedle.abs(), lessThan(.06));

      // يركّز ولسانه خارج فمه، ثم يفرح.
      final focused = const WorkersPose(3).kneelingFace;
      expect(focused.browKnit, greaterThan(.3));
      expect(focused.tongue, greaterThan(.8));
      final pleased = const WorkersPose(5.6).kneelingFace;
      expect(pleased.happy, greaterThan(.8));
      expect(pleased.grin, greaterThan(.8));
    });

    test('يدا العامل الواقف تتحركان بعكس بعضهما على العجلة', () {
      for (final time in [.3, .65, 1.1, 1.9, 2.4]) {
        final pose = WorkersPose(time);
        expect(pose.upperArm * pose.lowerArm, lessThanOrEqualTo(0), reason: '$time');
      }
    });

    test('اليدان تبقيان على حافة العجلة، والأصابع على العداد الصغير', () {
      Offset turned(Offset point, Offset center, double angle) {
        final d = point - center;
        return center +
            Offset(d.dx * math.cos(angle) - d.dy * math.sin(angle), d.dx * math.sin(angle) + d.dy * math.cos(angle));
      }

      // حافة العجلة الأمامية في الرسم، ونقطة قبض كل يد عليها.
      const rim = Rect.fromLTRB(226.4, 41.2, 231.74, 64.64);
      bool onRim(Offset point) {
        final x = (point.dx - rim.center.dx) / (rim.width / 2);
        final y = (point.dy - rim.center.dy) / (rim.height / 2);
        return x * x + y * y <= 1;
      }

      const waist = Offset(187, 104), hip = Offset(104, 152);
      const dial = Offset(35.1, 118.7);
      for (var time = 0.0; time < 20; time += .05) {
        final pose = WorkersPose(time);
        final upper = turned(turned(const Offset(228.5, 44), const Offset(197, 64), pose.upperArm), waist,
            pose.standingLean);
        final lower = turned(turned(const Offset(228.5, 62.5), const Offset(181, 66), pose.lowerArm), waist,
            pose.standingLean);
        expect(onRim(upper), isTrue, reason: 'upper hand at $time');
        expect(onRim(lower), isTrue, reason: 'lower hand at $time');

        final fingers = turned(turned(const Offset(37.5, 121.5), const Offset(92, 127), pose.reachingArm), hip,
            pose.kneelingLean);
        expect((fingers - dial).distance, lessThan(4.3), reason: 'fingers at $time');
        expect(pose.holdingArm.abs(), lessThanOrEqualTo(.06));
      }
    });
  });
}
