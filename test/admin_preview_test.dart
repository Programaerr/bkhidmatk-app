import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jaik/app.dart';
import 'package:jaik/data/models.dart';
import 'package:jaik/data/preview_repository.dart';
import 'package:jaik/state/app_state.dart';
import 'package:jaik/ui/admin/admin_shell.dart';
import 'package:jaik/ui/customer/customer_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('local preview opens as customer and allows switching to admin locally',
      () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(
      repository: PreviewRepository(),
      developmentAdminPreview: true,
    );

    await state.boot();

    expect(state.isAdmin, isFalse);
    expect(state.isLoggedIn, isTrue);
    expect(state.usesCloudAuth, isFalse);
    expect(state.user?.phone, '07701234567');

    state.openDevelopmentAdmin();
    expect(state.isAdmin, isTrue);
    state.returnToDevelopmentCustomer();
    expect(state.isAdmin, isFalse);
    state.dispose();
  });

  test('preview repository keeps reel links for the current session', () async {
    final repository = PreviewRepository();
    final id = await repository.createWork(OurWork(
      title: 'فيديو تجربة',
      videoUrl: 'https://example.com/demo.mp4',
      createdAt: DateTime.utc(2026),
    ));

    expect((await repository.listWorks()).single.id, id);
    await repository.setWorkActive(id, false);
    expect(await repository.listWorks(), isEmpty);
    expect(
        (await repository.listWorks(onlyActive: false)).single.active, isFalse);

    await repository.deleteWork(id);
    expect(await repository.workCount(), 0);
    await repository.close();
  });

  testWidgets('customer profile has a development-only dashboard entry',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = PreviewRepository();
    await repository.createWork(OurWork(
      title: 'ريل تجربة',
      videoUrl: 'https://example.com/watch?id=preview',
      createdAt: DateTime.utc(2026),
    ));
    final state = AppState(
      repository: repository,
      developmentAdminPreview: true,
    );
    await state.boot();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const JaikApp(),
      ),
    );
    expect(find.byType(CustomerShell), findsOneWidget);
    expect(find.text('ريلز'), findsOneWidget);

    await tester.tap(find.text('حسابي'));
    await tester.pumpAndSettle();
    expect(find.text('لوحة التحكم'), findsOneWidget);

    await tester.tap(find.text('لوحة التحكم'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminShell), findsOneWidget);
    await tester.tap(find.text('إدارة الريلز'));
    await tester.pumpAndSettle();
    expect(find.text('ريل تجربة'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'فيديو جديد');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'https://example.com/new-video.mp4',
    );
    await tester.tap(find.text('إضافة العمل'));
    await tester.pumpAndSettle();
    expect(find.text('فيديو جديد'), findsOneWidget);

    await tester.tap(find.text('واجهة الزبون'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerShell), findsOneWidget);
    await tester.tap(find.text('ريلز'));
    await tester.pumpAndSettle();
    expect(find.text('فيديو جديد'), findsOneWidget);
    state.dispose();
  });
}
