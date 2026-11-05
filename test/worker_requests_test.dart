import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jaik/core/theme.dart';
import 'package:jaik/data/models.dart';
import 'package:jaik/state/app_state.dart';
import 'package:jaik/ui/widgets/ui.dart';
import 'package:jaik/ui/worker/worker_requests_tab.dart';

import 'fake_repository.dart';

AppUser _worker() => AppUser(
      id: 9,
      name: 'حرفي',
      phone: '07701112233',
      passwordHash: '',
      role: 'worker',
      createdAt: DateTime(2026),
    );

Booking _booking(int id, String status, {String response = WorkerResponse.pending}) => Booking(
      id: id,
      customerId: 1,
      serviceId: 1,
      workerId: 5,
      scheduledAt: DateTime(2026, 11, 8),
      slot: '10:00',
      address: status == BookingStatus.dispatched ? 'الكرادة، شارع 52' : '',
      status: status,
      total: 25000,
      createdAt: DateTime(2026, 11, 5),
      workerResponse: response,
      serviceTitle: 'تصليح تسرب $id',
      customerName: 'زبون $id',
      customerPhone: status == BookingStatus.dispatched ? '07701234567' : null,
    );

class _Repo extends FakeRepo {
  _Repo(this.bookings) : super(customer: _worker());

  final List<Booking> bookings;
  final answers = <(int, bool)>[];

  @override
  Future<List<Booking>> bookingsForWorker(AppUser worker) async => bookings;

  @override
  Future<void> respondToBooking(int bookingId, {required bool accept}) async =>
      answers.add((bookingId, accept));
}

Future<void> _pump(WidgetTester tester, _Repo repo) async {
  SharedPreferences.setMockInitialValues({});
  tester.view
    ..physicalSize = const Size(392, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: AppState(repository: repo)..user = _worker(),
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: const Scaffold(body: WorkerRequestsTab()),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('الطلب الجديد يُؤكَّد من الحرفي، ولا تظهر له بيانات الزبون قبل الإرسال', (tester) async {
    final repo = _Repo([_booking(1, BookingStatus.pending)]);
    await _pump(tester, repo);
    expect(find.text('تصليح تسرب 1'), findsOneWidget);
    expect(find.text('الزبون: زبون 1'), findsOneWidget);
    expect(find.byIcon(Icons.location_on_outlined), findsNothing);
    expect(find.text('اتصال بالزبون'), findsNothing);

    await tester.tap(find.widgetWithText(PrimaryButton, 'موافق'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(repo.answers, [(1, true)]);
  });

  testWidgets('بعد إرسال الإدارة له يرى العنوان وزر الاتصال بالزبون', (tester) async {
    final repo = _Repo([
      _booking(2, BookingStatus.dispatched, response: WorkerResponse.accepted),
    ]);
    await _pump(tester, repo);
    expect(find.text('الكرادة، شارع 52'), findsOneWidget);
    expect(find.text('اتصال بالزبون'), findsOneWidget);
    expect(find.text('موافق'), findsNothing);
  });

  testWidgets('الاعتذار يسأل أولاً ثم يرسل الرد', (tester) async {
    final repo = _Repo([_booking(3, BookingStatus.confirmed)]);
    await _pump(tester, repo);
    await tester.tap(find.widgetWithText(SecondaryButton, 'اعتذار'));
    await tester.pumpAndSettle();
    expect(find.text('الاعتذار عن الحجز؟'), findsOneWidget);
    await tester.tap(find.widgetWithText(PrimaryButton, 'اعتذار'));
    await tester.pumpAndSettle();
    expect(repo.answers, [(3, false)]);
  });
}
