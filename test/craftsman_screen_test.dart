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

Future<void> _pump(WidgetTester tester, _Repo repo, Widget screen) async {
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

Future<void> _fill(WidgetTester tester, {String phone = '07701234567', String age = '28'}) async {
  await tester.enterText(_field('الاسم'), 'كرار عبد الله');
  await tester.enterText(_field('الهاتف'), phone);
  await tester.enterText(_field('العمر'), age);
  await tester.enterText(_field('المهنة'), 'كهربائي');
  await tester.enterText(_field('الخبرة'), '5');
  await tester.enterText(_field('النبذة'), 'عملت في تأسيس البيوت');
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

  testWidgets('الخانة الخطأ تهتز، ويرجع لونها بمجرد تصحيحها', (tester) async {
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

    await tester.enterText(_field('الاسم'), 'كر');
    await tester.pumpAndSettle();
    expect(find.text('أدخل الاسم الكامل'), findsOneWidget);
    await tester.enterText(_field('الاسم'), 'كرار');
    await tester.pumpAndSettle();
    expect(find.text('أدخل الاسم الكامل'), findsNothing);
  });

  testWidgets('خانة المحافظة تفتح القائمة وتأخذ المختار', (tester) async {
    await _pump(tester, _Repo(), const CraftsmanScreen());
    await tester.tap(find.text('بغداد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('البصرة'));
    await tester.pumpAndSettle();
    expect(find.text('البصرة'), findsOneWidget);
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
