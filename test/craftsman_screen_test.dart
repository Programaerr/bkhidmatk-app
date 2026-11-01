import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:jaik/core/theme.dart';
import 'package:jaik/data/models.dart';
import 'package:jaik/state/app_state.dart';
import 'package:jaik/ui/admin/admin_applications.dart';
import 'package:jaik/ui/auth/craftsman_screen.dart';
import 'package:jaik/ui/auth/push_key.dart';
import 'package:jaik/ui/auth/raised_field.dart';
import 'package:jaik/ui/widgets/ui.dart';

import 'fake_repository.dart';

class _Repo extends FakeRepo {
  _Repo({this.pending = false, this.saved = const []});

  final bool pending;
  final List<CraftsmanApplication> saved;
  final created = <CraftsmanApplication>[];
  final acceptedPhones = <String>[];
  final rejectedIds = <int>[];

  @override
  Future<bool> hasPendingApplication(String phone) async => pending;

  @override
  Future<int> createApplication(CraftsmanApplication application) async {
    created.add(application);
    return 1;
  }

  @override
  Future<List<CraftsmanApplication>> listApplications() async => saved;

  @override
  Future<void> acceptApplication(CraftsmanApplication application) async {
    acceptedPhones.add(application.phone);
  }

  @override
  Future<void> rejectApplication(int id) async => rejectedIds.add(id);
}

class _SlowRepo extends _Repo {
  final answer = Completer<bool>();

  @override
  Future<bool> hasPendingApplication(String phone) => answer.future;
}

Future<void> _pump(
  WidgetTester tester,
  _Repo repo,
  Widget screen, {
  Size size = const Size(412, 1600),
}) async {
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
                onPressed: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
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

const _fieldOrder = ['الاسم', 'الهاتف', 'العمر', 'العنوان', 'المهنة', 'الخبرة', 'النبذة'];

Future<void> _chooseCity(WidgetTester tester, String city) async {
  await tester.ensureVisible(find.byType(RaisedPicker));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(RaisedPicker));
  await tester.pumpAndSettle();
  await tester.tap(find.text(city).last);
  await tester.pumpAndSettle();
}

Future<void> _fill(
  WidgetTester tester, {
  String phone = '07701234567',
  String age = '28',
  String? city = 'بغداد',
}) async {
  await tester.enterText(_field('الاسم'), 'كرار عبد الله');
  await tester.enterText(_field('الهاتف'), phone);
  await tester.enterText(_field('العمر'), age);
  await tester.enterText(_field('المهنة'), 'كهربائي');
  await tester.enterText(_field('الخبرة'), '5');
  await tester.enterText(_field('النبذة'), 'عملت في تأسيس البيوت');
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

CraftsmanApplication _application({int id = 7, String status = CraftsmanApplication.pending}) =>
    CraftsmanApplication(
      id: id,
      name: 'كرار عبد الله',
      phone: '07701234567',
      age: 28,
      city: 'بغداد',
      trade: 'كهربائي',
      experienceYears: 5,
      status: status,
      createdAt: DateTime(2026, 10, 31),
    );

void main() {
  testWidgets('الطلب الكامل يصل إلى الشركة وتظهر رسالة الوصول', (tester) async {
    final repo = _Repo();
    await _pump(tester, repo, const CraftsmanScreen());
    await _fill(tester);
    await tester.tap(find.text('إرسال الطلب إلى الشركة'));
    await tester.pumpAndSettle();

    final sent = repo.created.single;
    expect(sent.name, 'كرار عبد الله');
    expect(sent.phone, '07701234567');
    expect(sent.age, 28);
    expect(sent.city, 'بغداد');
    expect(sent.trade, 'كهربائي');
    expect(sent.experienceYears, 5);
    expect(sent.about, 'عملت في تأسيس البيوت');
    expect(sent.status, CraftsmanApplication.pending);
    expect(find.text('وصل طلبك إلى الشركة'), findsOneWidget);
  });

  testWidgets('الأرقام العربية تُحفظ أرقاماً صحيحة', (tester) async {
    final repo = _Repo();
    await _pump(tester, repo, const CraftsmanScreen());
    await _fill(tester, phone: '٠٧٧٠١٢٣٤٥٦٧', age: '٢٨');
    await tester.tap(find.text('إرسال الطلب إلى الشركة'));
    await tester.pumpAndSettle();

    expect(repo.created.single.phone, '07701234567');
    expect(repo.created.single.age, 28);
  });

  testWidgets('الحقول الناقصة لا تُرسل', (tester) async {
    final repo = _Repo();
    await _pump(tester, repo, const CraftsmanScreen());
    await tester.tap(find.text('إرسال الطلب إلى الشركة'));
    await tester.pumpAndSettle();

    expect(repo.created, isEmpty);
    expect(find.text('أدخل الاسم الكامل'), findsOneWidget);
    expect(find.text('أدخل مهنتك'), findsOneWidget);
  });

  testWidgets('الرقم الذي له طلب قيد المراجعة لا يقدّم مرة ثانية', (tester) async {
    final repo = _Repo(pending: true);
    await _pump(tester, repo, const CraftsmanScreen());
    await _fill(tester);
    await tester.tap(find.text('إرسال الطلب إلى الشركة'));
    await tester.pumpAndSettle();

    expect(repo.created, isEmpty);
    expect(find.text('يوجد طلب قيد المراجعة بهذا الرقم'), findsOneWidget);
  });

  testWidgets('الرقم من الشاشة الأولى جاهز في الحقل', (tester) async {
    await _pump(tester, _Repo(), const CraftsmanScreen(initialPhone: '07701234567'));
    expect(find.text('07701234567'), findsOneWidget);
  });

  testWidgets('زر عودة كزبون يرجع إلى الشاشة الأولى', (tester) async {
    await _pump(tester, _Repo(), const CraftsmanScreen());
    expect(find.text('الشاشة الأولى'), findsNothing);

    await tester.tap(find.text('عودة كزبون'));
    await tester.pumpAndSettle();
    expect(find.text('الشاشة الأولى'), findsOneWidget);
  });

  testWidgets('زر عودة كزبون موجود أيضاً بعد إرسال الطلب', (tester) async {
    await _pump(tester, _Repo(), const CraftsmanScreen());
    await _fill(tester);
    await tester.tap(find.text('إرسال الطلب إلى الشركة'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('عودة كزبون'));
    await tester.pumpAndSettle();
    expect(find.text('الشاشة الأولى'), findsOneWidget);
  });

  testWidgets('الخانة ترتفع عند الكتابة فيها ويتلاشى نصها الدليل', (tester) async {
    await _pump(tester, _Repo(), const CraftsmanScreen());
    final name = find.descendant(of: _field('الاسم'), matching: find.byType(EditableText));
    final atRest = tester.getRect(name);
    double hintOpacity() => tester
        .widget<Opacity>(find.ancestor(of: find.text('مثال: أحمد سعد'), matching: find.byType(Opacity)).first)
        .opacity;
    expect(hintOpacity(), 1);

    await tester.tap(_field('الاسم'));
    await tester.pumpAndSettle();
    final focused = tester.getRect(name);
    expect(focused.center.dy, closeTo(atRest.center.dy - 3, .01));
    expect(focused.width, closeTo(atRest.width * 1.01, .01));
    expect(hintOpacity(), 0);
  });

  testWidgets('لمس أي مكان في الخانة يفتح الكتابة فيها', (tester) async {
    await _pump(tester, _Repo(), const CraftsmanScreen());
    await tester.tapAt(tester.getRect(_field('الاسم')).topCenter - const Offset(0, 10));
    await tester.pump();
    expect(tester.widget<TextField>(_field('الاسم')).focusNode!.hasFocus, isTrue);
  });

  testWidgets('الخانة الخطأ تهتز، وتختفي حمرتها بمجرد الكتابة فيها', (tester) async {
    await _pump(tester, _Repo(), const CraftsmanScreen());
    final name = find.descendant(of: _field('الاسم'), matching: find.byType(EditableText));
    final atRest = tester.getRect(name);

    await tester.tap(find.text('إرسال الطلب إلى الشركة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 125));
    expect(tester.getRect(name).left, closeTo(atRest.left - 5, .01));
    await tester.pump(const Duration(milliseconds: 125));
    expect(tester.getRect(name).left, closeTo(atRest.left + 5, .01));
    await tester.pumpAndSettle();
    expect(tester.getRect(name).left, atRest.left);
    expect(find.text('أدخل الاسم الكامل'), findsOneWidget);

    await tester.enterText(_field('الاسم'), 'ك');
    await tester.pumpAndSettle();
    expect(find.text('أدخل الاسم الكامل'), findsNothing);

    await tester.tap(find.text('إرسال الطلب إلى الشركة'));
    await tester.pumpAndSettle();
    expect(find.text('أدخل الاسم الكامل'), findsOneWidget);
  });

  testWidgets('الكتابة وإطارها بالأسود، والأحمر للخطأ فقط', (tester) async {
    await _pump(tester, _Repo(), const CraftsmanScreen());
    await tester.tap(find.text('إرسال الطلب إلى الشركة'));
    await tester.pumpAndSettle();
    final name = find.byType(RaisedField).at(0);
    _expectBorder(tester, name, const Color(0xFFFF4D4D));

    await tester.enterText(_field('الاسم'), 'كرار');
    await tester.pumpAndSettle();
    _expectBorder(tester, name, AppColors.ink);
    final field = tester.widget<TextField>(_field('الاسم'));
    expect(field.style!.color, AppColors.ink);
    expect(field.cursorColor, AppColors.ink);
    for (final label in _fieldOrder) {
      expect(tester.widget<TextField>(_field(label)).style!.color, AppColors.ink, reason: label);
    }

    await _chooseCity(tester, 'البصرة');
    expect(tester.widget<Text>(find.text('البصرة')).style!.color, AppColors.ink);
    expect(tester.widget<Icon>(find.byIcon(Icons.expand_more_rounded)).color, AppColors.ink);
  });

  testWidgets('رسالة الطلب القائم تختفي بتعديل الرقم', (tester) async {
    await _pump(tester, _Repo(pending: true), const CraftsmanScreen());
    await _fill(tester);
    await tester.tap(find.text('إرسال الطلب إلى الشركة'));
    await tester.pumpAndSettle();
    expect(find.text('يوجد طلب قيد المراجعة بهذا الرقم'), findsOneWidget);

    await tester.enterText(_field('الهاتف'), '07701234568');
    await tester.pumpAndSettle();
    expect(find.text('يوجد طلب قيد المراجعة بهذا الرقم'), findsNothing);
  });

  testWidgets('النقطة الحمراء تختفي بملء الخانة وترجع بتفريغها', (tester) async {
    await _pump(tester, _Repo(), const CraftsmanScreen());
    const labels = {
      'الاسم الكامل': 'الاسم',
      'رقم الهاتف': 'الهاتف',
      'العمر': 'العمر',
      'المهنة': 'المهنة',
      'سنوات الخبرة': 'الخبرة',
    };
    for (final MapEntry(key: label, value: field) in labels.entries) {
      expect(_starShown(tester, label), isTrue, reason: label);
      await tester.enterText(_field(field), '5');
      await tester.pump();
      expect(_starShown(tester, label), isFalse, reason: label);
      await tester.enterText(_field(field), '');
      await tester.pump();
      expect(_starShown(tester, label), isTrue, reason: label);
    }
    await tester.pumpAndSettle();

    expect(_starShown(tester, 'المحافظة'), isTrue);
    await _chooseCity(tester, 'البصرة');
    expect(_starShown(tester, 'المحافظة'), isFalse);
  });

  testWidgets('الهاتف والعمر والخبرة تقبل الأرقام فقط', (tester) async {
    await _pump(tester, _Repo(), const CraftsmanScreen());
    String typed(String label) => tester.widget<TextField>(_field(label)).controller!.text;

    await tester.enterText(_field('الهاتف'), '0780abc990xyz09901234');
    expect(typed('الهاتف'), '07809900990');
    await tester.enterText(_field('العمر'), '2a8b');
    expect(typed('العمر'), '28');
    await tester.enterText(_field('العمر'), '٢٨٩');
    expect(typed('العمر'), '28');
    await tester.enterText(_field('الخبرة'), 'خمس');
    expect(typed('الخبرة'), isEmpty);
    await tester.enterText(_field('الخبرة'), '5x');
    expect(typed('الخبرة'), '5');

    // باقي الخانات تبقى تقبل الكلام.
    await tester.enterText(_field('الاسم'), 'كرار 2');
    expect(typed('الاسم'), 'كرار 2');
    await tester.pumpAndSettle();
  });

  testWidgets('خانة المحافظة تبدأ فارغة وتأخذ المختار', (tester) async {
    await _pump(tester, _Repo(), const CraftsmanScreen());
    expect(find.text('بغداد'), findsNothing);
    expect(find.text('اختر المحافظة'), findsOneWidget);

    await _chooseCity(tester, 'البصرة');
    expect(find.text('البصرة'), findsOneWidget);
    expect(find.text('اختر المحافظة'), findsNothing);
  });

  testWidgets('الإرسال بدون محافظة يظهر خطأها، ويختفي عند الاختيار', (tester) async {
    final repo = _Repo();
    await _pump(tester, repo, const CraftsmanScreen());
    await _fill(tester, city: null);
    await tester.tap(find.text('إرسال الطلب إلى الشركة'));
    await tester.pumpAndSettle();
    expect(find.text('اختر محافظتك'), findsOneWidget);
    expect(repo.created, isEmpty);

    await _chooseCity(tester, 'البصرة');
    expect(find.text('اختر محافظتك'), findsNothing);
    await tester.tap(find.text('إرسال الطلب إلى الشركة'));
    await tester.pumpAndSettle();
    expect(repo.created.single.city, 'البصرة');
  });

  testWidgets('الإرسال مع خانة خطأ ينقل الصفحة إليها', (tester) async {
    final repo = _Repo();
    await _pump(tester, repo, const CraftsmanScreen(), size: const Size(412, 600));
    await _fill(tester, age: '5');
    final send = find.text('إرسال الطلب إلى الشركة');
    await tester.ensureVisible(send);
    await tester.pumpAndSettle();
    final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
    expect(tester.getTopLeft(find.text('العمر')).dy, lessThan(appBarBottom));

    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('العمر')).dy, greaterThanOrEqualTo(appBarBottom));
    expect(tester.getBottomLeft(find.text('أدخل عمراً صحيحاً')).dy, lessThanOrEqualTo(600));
    expect(repo.created, isEmpty);
  });

  testWidgets('الرقم بدون الصفر يُقبل ويُحفظ بالصفر', (tester) async {
    final repo = _Repo();
    await _pump(tester, repo, const CraftsmanScreen());
    await _fill(tester, phone: '7701234567');
    await tester.tap(find.text('إرسال الطلب إلى الشركة'));
    await tester.pumpAndSettle();
    expect(repo.created.single.phone, '07701234567');
  });

  testWidgets('زر الإرسال وحده أصفر', (tester) async {
    await _pump(tester, _Repo(), const CraftsmanScreen());
    PushKey key(String label) =>
        tester.widget<PushKey>(find.ancestor(of: find.text(label), matching: find.byType(PushKey)));
    expect(key('إرسال الطلب إلى الشركة').yellow, isTrue);
    expect(key('عودة كزبون').yellow, isFalse);
  });

  testWidgets('زر الإرسال يبقى منخفضاً أثناء الانتظار ولا يرسل مرتين', (tester) async {
    final repo = _SlowRepo();
    await _pump(tester, repo, const CraftsmanScreen());
    await _fill(tester);
    await tester.tap(find.text('إرسال الطلب إلى الشركة'));
    await tester.pump();

    final send = find.byType(PushKey).first;
    expect(tester.widget<PushKey>(send).held, isTrue);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(send);
    await tester.pump();

    repo.answer.complete(false);
    await tester.pumpAndSettle();
    expect(repo.created, hasLength(1));
  });

  testWidgets('الإدارة تقرأ الطلب وتقبله', (tester) async {
    final repo = _Repo(saved: [_application()]);
    await _pump(tester, repo, const AdminApplicationsScreen());
    expect(find.text('قيد المراجعة'), findsOneWidget);

    await tester.tap(find.text('كرار عبد الله'));
    await tester.pumpAndSettle();
    expect(find.text('28 سنة'), findsOneWidget);

    await tester.tap(find.text('قبول'));
    await tester.pumpAndSettle();
    expect(repo.acceptedPhones, ['07701234567']);
  });

  testWidgets('الإدارة ترفض الطلب', (tester) async {
    final repo = _Repo(saved: [_application()]);
    await _pump(tester, repo, const AdminApplicationsScreen());
    await tester.tap(find.text('كرار عبد الله'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('رفض'));
    await tester.pumpAndSettle();
    expect(repo.rejectedIds, [7]);
  });

  testWidgets('الطلب الذي بُتّ فيه لا تظهر فيه أزرار القبول والرفض', (tester) async {
    final repo = _Repo(saved: [_application(status: CraftsmanApplication.accepted)]);
    await _pump(tester, repo, const AdminApplicationsScreen());
    await tester.tap(find.text('كرار عبد الله'));
    await tester.pumpAndSettle();

    expect(find.text('قبول'), findsNothing);
    expect(find.text('رفض'), findsNothing);
  });
}
