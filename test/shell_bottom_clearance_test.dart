import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jaik/core/theme.dart';
import 'package:jaik/data/models.dart';
import 'package:jaik/state/app_state.dart';
import 'package:jaik/ui/customer/customer_shell.dart';
import 'package:jaik/ui/worker/worker_shell.dart';

import 'fake_repository.dart';

AppUser _user(String role) => AppUser(
      id: 1,
      name: 'مستخدم',
      phone: '07701234567',
      passwordHash: '',
      role: role,
      createdAt: DateTime(2026),
    );

class _Repo extends FakeRepo {
  _Repo(String role) : super(customer: _user(role));

  List<Booking> get _bookings => [
        for (var i = 1; i <= 8; i++)
          Booking(
            id: i,
            customerId: 1,
            serviceId: 1,
            workerId: 1,
            scheduledAt: DateTime(2026, 11, 8),
            slot: '10:00',
            address: 'عنوان',
            total: 25000,
            createdAt: DateTime(2026, 11, 5),
            serviceTitle: 'خدمة $i',
            customerName: 'زبون $i',
          ),
      ];

  @override
  Future<List<Booking>> bookingsForCustomer(int customerId, {String? status}) async => _bookings;

  @override
  Future<List<Booking>> bookingsForWorker(AppUser worker) async => _bookings;

  @override
  Future<List<Worker>> listWorkers({int? categoryId, bool onlyAvailable = false}) async => [
        for (var i = 1; i <= 12; i++)
          Worker(id: i, name: 'حرفي $i', phone: '', specialty: 'شغل $i', rating: 4.5),
      ];
}

Future<double> _lowestTextAfterScrollingToEnd(WidgetTester tester) async {
  final list = find.byType(ListView).hitTestable().first;
  for (var i = 0; i < 8; i++) {
    await tester.fling(list, const Offset(0, -600), 3000);
    await tester.pump(const Duration(milliseconds: 400));
  }
  final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  var lowest = 0.0;
  for (final text in find.descendant(of: list, matching: find.byType(Text)).evaluate()) {
    final rect = tester.getRect(find.byWidget(text.widget).first);
    if (rect.top < screen && rect.bottom > lowest) lowest = rect.bottom;
  }
  return lowest;
}

Future<void> _pump(WidgetTester tester, String role, Widget shell) async {
  SharedPreferences.setMockInitialValues({});
  tester.view
    ..physicalSize = const Size(392, 700)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: AppState(repository: _Repo(role))..user = _user(role),
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: shell,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

/// آخر ما في كل تبويب قائمة يجب أن يمكن النزول إليه فوق شريط التنقل، في كل الغلافات.
void main() {
  Future<void> check(WidgetTester tester, List<String> tabs) async {
    final navTop = tester.getRect(find.byKey(const ValueKey('glass-navigation-bar'))).top;
    for (final tab in tabs) {
      await tester.tap(find.text(tab).last);
      await tester.pump(const Duration(milliseconds: 400));
      if (find.byType(ListView).hitTestable().evaluate().isEmpty) continue;
      final lowest = await _lowestTextAfterScrollingToEnd(tester);
      expect(lowest, lessThanOrEqualTo(navTop + .5), reason: tab);
    }
  }

  testWidgets('غلاف الزبون: آخر كل تبويب فوق الشريط', (tester) async {
    await _pump(tester, 'customer', const CustomerShell());
    await check(tester, ['الرئيسية', 'الحرفيين', 'حجوزاتي', 'حسابي']);
  });

  testWidgets('غلاف الحرفي: آخر طلباته فوق الشريط', (tester) async {
    await _pump(tester, 'worker', const WorkerShell());
    await check(tester, ['طلباتي', 'حسابي']);
  });
}
