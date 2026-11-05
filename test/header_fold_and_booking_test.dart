import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jaik/core/theme.dart';
import 'package:jaik/data/models.dart';
import 'package:jaik/state/app_state.dart';
import 'package:jaik/ui/admin/admin_shell.dart';
import 'package:jaik/ui/auth/push_key.dart';
import 'package:jaik/ui/customer/booking_screen.dart';
import 'package:jaik/ui/customer/craftsman_info_screen.dart';
import 'package:jaik/ui/customer/customer_shell.dart';
import 'package:jaik/ui/customer/home_keys.dart';
import 'package:jaik/ui/widgets/ui.dart';

import 'fake_repository.dart';
import 'route_frames.dart';

AppUser _user({String role = 'customer'}) => AppUser(
      id: 1,
      name: 'زبون تجريبي',
      phone: '07701234567',
      passwordHash: '',
      role: role,
      city: 'بغداد',
      address: 'بغداد، الكرادة، قرب الساحة',
      createdAt: DateTime(2026),
    );

class _Repo extends FakeRepo {
  _Repo({super.customer});

  final worker = const Worker(
    id: 7,
    name: 'حرفي سباك',
    phone: '',
    specialty: 'سباكة',
    categoryId: 3,
    rating: 4.5,
  );

  @override
  Future<List<Worker>> listWorkers({int? categoryId, bool onlyAvailable = false}) async =>
      [worker];

  @override
  Future<List<Service>> listServices({
    int? categoryId,
    String query = '',
    bool onlyActive = true,
    int? limit,
  }) async =>
      [
        Service(
          id: 1,
          categoryId: 3,
          title: 'تصليح تسرب',
          description: '',
          price: 15000,
          durationMinutes: 60,
          createdAt: DateTime(2026),
        ),
      ];
}

Future<void> _pump(WidgetTester tester, Widget home, {Size size = const Size(392, 700)}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: AppState(repository: _Repo(customer: _user()))..user = _user(),
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: home,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 60));
}

void main() {
  testWidgets('الجهة الصفراء تنطوي إلى شريط عند نزول الصفحة وتفتح عند العودة إلى الأعلى', (tester) async {
    await _pump(tester, const CustomerShell());
    final open = tester.getSize(find.byType(HomeHill).first).height;

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await tester.pump();
    final folded = tester.getSize(find.byType(HomeHill).first).height;
    expect(folded, lessThan(open - 20));
    expect(folded, greaterThan(40));

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 800));
    await tester.pump();
    expect(tester.getSize(find.byType(HomeHill).first).height, closeTo(open, .5));
  });

  testWidgets('صفحة الحرفي فيها خدماته، والضغط على احجز يفتح الحجز بالحرفي نفسه', (tester) async {
    final repo = _Repo(customer: _user());
    await _pump(tester, CraftsmanInfoScreen(worker: repo.worker));
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('تصليح تسرب'), findsOneWidget);

    await tester.tap(find.widgetWithText(PrimaryButton, 'احجز'));
    await tester.pump();
    await pumpRouteFrames(tester);
    await tester.pumpAndSettle();
    final booking = tester.widget<BookingScreen>(find.byType(BookingScreen));
    expect(booking.workerId, 7);
    expect(booking.service.title, 'تصليح تسرب');
  });

  testWidgets('لوحة التحكم: بلا عين معاينة، وزر رجوع اعتيادي، وبلا شريط علوي مكرر', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view
      ..physicalSize = const Size(392, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: AppState(repository: _Repo(customer: _user(role: 'admin')))
          ..user = _user(role: 'admin'),
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminShell()),
                ),
                child: const Text('افتح'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('افتح'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    expect(find.byType(PushKeyBack), findsOneWidget);
    await tester.tap(find.byType(PushKeyBack));
    await tester.pumpAndSettle();
    expect(find.text('افتح'), findsOneWidget);
  });
}
