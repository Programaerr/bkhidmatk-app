import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:jaik/core/theme.dart';
import 'package:jaik/data/models.dart';
import 'package:jaik/state/app_state.dart';
import 'package:jaik/ui/admin/admin_applications.dart';
import 'package:jaik/ui/auth/craftsman_screen.dart';

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

Finder _field(String label) => find.byType(TextFormField).at(_fieldOrder.indexOf(label));

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
