import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jaik/core/theme.dart';
import 'package:jaik/data/models.dart';
import 'package:jaik/state/app_state.dart';
import 'package:jaik/ui/admin/admin_shell.dart';

import 'fake_repository.dart';

AppUser _admin() => AppUser(
      id: 1,
      name: 'المدير',
      phone: '07700000000',
      passwordHash: '',
      role: 'admin',
      createdAt: DateTime(2026),
    );

class _Repo extends FakeRepo {
  _Repo() : super(customer: _admin());

  @override
  Future<List<Booking>> allBookings({String? status, String query = ''}) async => [
        for (var i = 1; i <= 8; i++)
          Booking(
            id: i,
            customerId: 2,
            serviceId: 1,
            scheduledAt: DateTime(2026, 11, 8),
            slot: '10:00',
            address: 'عنوان',
            total: 25000,
            createdAt: DateTime(2026, 11, 5),
            serviceTitle: 'خدمة $i',
            customerName: 'زبون $i',
          ),
      ];
}

/// أسفل أي نص ظاهر في القائمة، بعد النزول بها إلى آخرها.
Future<double> _lowestTextAfterScrollingToEnd(WidgetTester tester) async {
  final list = find.byType(ListView).hitTestable().first;
  for (var i = 0; i < 8; i++) {
    await tester.fling(list, const Offset(0, -600), 3000);
    await tester.pumpAndSettle();
  }
  final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  var lowest = 0.0;
  for (final text in find.descendant(of: list, matching: find.byType(Text)).evaluate()) {
    final rect = tester.getRect(find.byWidget(text.widget).first);
    if (rect.top < screen && rect.bottom > lowest) lowest = rect.bottom;
  }
  return lowest;
}

void main() {
  // لوحة التحكم كانت تمتد خلف الشريط الزجاجي، فيخفي آخر ما فيها ولا يمكن النزول إليه.
  testWidgets('كل تبويبات لوحة التحكم تنزل إلى آخرها فوق شريط التنقل لا خلفه', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view
      ..physicalSize = const Size(392, 700)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: AppState(repository: _Repo())..user = _admin(),
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
          home: const AdminShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final navTop = tester.getRect(find.byKey(const ValueKey('glass-navigation-bar'))).top;
    for (final tab in ['الرئيسية', 'الحجوزات', 'الخدمات', 'الأعمال', 'المزيد']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      if (find.byType(ListView).hitTestable().evaluate().isEmpty) continue;
      final lowest = await _lowestTextAfterScrollingToEnd(tester);
      expect(lowest, lessThanOrEqualTo(navTop + .5), reason: tab);
    }
  });

  testWidgets('الرئيسية: آخر بطاقة في «أحدث الحجوزات» تظهر كلها عند النزول', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view
      ..physicalSize = const Size(392, 700)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: AppState(repository: _Repo())..user = _admin(),
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
          home: const AdminShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _lowestTextAfterScrollingToEnd(tester);
    // الأحدث أربعة، وآخرها ظاهر بعد النزول.
    expect(find.text('زبون 4').hitTestable(), findsOneWidget);
  });
}
