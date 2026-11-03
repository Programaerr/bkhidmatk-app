import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import 'package:jaik/core/theme.dart';
import 'package:jaik/data/models.dart';
import 'package:jaik/data/repository_supabase.dart';
import 'package:jaik/state/app_state.dart';
import 'package:jaik/ui/auth/truck_scene.dart';
import 'package:jaik/ui/customer/bookings_tab.dart';
import 'package:jaik/ui/customer/customer_shell.dart';
import 'package:jaik/ui/customer/home_tab.dart';
import 'package:jaik/ui/customer/messages_screen.dart';
import 'package:jaik/ui/customer/our_work_tab.dart';
import 'package:jaik/ui/customer/profile_tab.dart';
import 'package:jaik/ui/customer/technicians_tab.dart';
import 'package:jaik/ui/widgets/quick_route.dart';
import 'package:jaik/ui/widgets/realtime_refresh.dart';

import 'fake_repository.dart';

AppUser _customer() => AppUser(
      id: 1,
      name: 'زبون تجريبي',
      phone: '07701234567',
      passwordHash: '',
      role: 'customer',
      createdAt: DateTime(2026),
    );

/// مستودع يعرف هل تستمع إليه صفحة.
class _WatchedRepo extends FakeRepo {
  _WatchedRepo() : super(customer: _customer());

  final controller = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => controller.stream;
}

Future<void> _pumpApp(WidgetTester tester, Widget home, _WatchedRepo repo) async {
  SharedPreferences.setMockInitialValues({});
  tester.view
    ..physicalSize = const Size(392, 825)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: AppState(repository: repo)..user = _customer(),
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

Future<void> _openOver(WidgetTester tester, Widget page) async {
  Navigator.of(tester.element(find.byType(Scaffold).first)).push(
    QuickRoute<void>(builder: (_) => page),
  );
  await tester.pump();
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _goBack(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
  await tester.pump();
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

class _CountingPage extends StatefulWidget {
  const _CountingPage({required this.loads});

  final ValueNotifier<int> loads;

  @override
  State<_CountingPage> createState() => _CountingPageState();
}

class _CountingPageState extends State<_CountingPage> with RealtimeRefresh<_CountingPage> {
  @override
  void onRealtimeChange() => widget.loads.value++;

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('الصفحة'));
}

Finder _anyState<T>() => find.byType(T, skipOffstage: false);

void main() {
  group('التبويبات', () {
    testWidgets('عند الدخول يُبنى التبويب الأول فقط', (tester) async {
      await _pumpApp(tester, const CustomerShell(), _WatchedRepo());
      expect(find.byType(HomeTab), findsOneWidget);
      expect(_anyState<BookingsTab>(), findsNothing);
      expect(_anyState<OurWorkTab>(), findsNothing);
      expect(_anyState<ProfileTab>(), findsNothing);
      expect(_anyState<TechniciansTab>(), findsNothing);
    });

    testWidgets('التبويب يُبنى عند فتحه ويبقى بعد مغادرته', (tester) async {
      await _pumpApp(tester, const CustomerShell(), _WatchedRepo());
      await tester.tap(find.text('حجوزاتي'));
      await tester.pump();
      expect(find.byType(BookingsTab), findsOneWidget);
      await tester.tap(find.text('الرئيسية').last);
      await tester.pump();
      expect(_anyState<BookingsTab>(), findsOneWidget);
      expect(_anyState<TechniciansTab>(), findsNothing);
    });

    testWidgets('تبديل التبويب لا يعيد بناء التبويبات الأخرى', (tester) async {
      await _pumpApp(tester, const CustomerShell(), _WatchedRepo());
      final home = tester.widget<HomeTab>(find.byType(HomeTab));
      await tester.tap(find.text('حجوزاتي'));
      await tester.pump();
      final bookings = tester.widget<BookingsTab>(find.byType(BookingsTab));
      await tester.tap(find.text('حسابي'));
      await tester.pump();
      expect(identical(tester.widget<HomeTab>(_anyState<HomeTab>()), home), isTrue);
      expect(identical(tester.widget<BookingsTab>(_anyState<BookingsTab>()), bookings), isTrue);
    });

    testWidgets('ما خلف التبويب الظاهر لا يتحرك', (tester) async {
      await _pumpApp(tester, const CustomerShell(), _WatchedRepo());
      bool moves<T>() => TickerMode.valuesOf(tester.element(_anyState<T>())).enabled;
      expect(moves<HomeTab>(), isTrue);
      await tester.tap(find.text('الحرفيين').last);
      await tester.pump();
      expect(moves<HomeTab>(), isFalse);
      expect(moves<TechniciansTab>(), isTrue);
    });

    testWidgets('الرجوع إلى تبويب يحدّث بياناته', (tester) async {
      final repo = _CountingCategoriesRepo();
      await _pumpApp(tester, const CustomerShell(), repo);
      await tester.tap(find.text('الحرفيين').last);
      await tester.pump();
      final opened = repo.workerLists;
      await tester.tap(find.text('حسابي'));
      await tester.pump(const Duration(seconds: 1));
      expect(repo.workerLists, opened);

      await tester.tap(find.text('الحرفيين').last);
      await tester.pump();
      expect(repo.workerLists, opened);
      await tester.pump(const Duration(milliseconds: 400));
      expect(repo.workerLists, opened + 1);
    });
  });

  group('الصفحة والسيرفر', () {
    testWidgets('الصفحة المخفية لا تحدّث شيئاً، وتحدّث عند رجوعها بعد انتهاء الانتقال', (tester) async {
      final loads = ValueNotifier(0);
      await _pumpApp(tester, _CountingPage(loads: loads), _WatchedRepo());
      expect(loads.value, 0);

      await _openOver(tester, const Scaffold(body: Text('فوقها')));
      await tester.pump(const Duration(seconds: 2));
      expect(loads.value, 0);

      await _goBack(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(loads.value, 1);
    });

    testWidgets('الصفحات العادية لا تفتح اتصالاً بالسيرفر', (tester) async {
      final repo = _WatchedRepo();
      await _pumpApp(tester, const CustomerShell(), repo);
      expect(repo.controller.hasListener, isFalse);
      await tester.tap(find.text('حجوزاتي'));
      await tester.pump();
      expect(repo.controller.hasListener, isFalse);
    });

    testWidgets('المحادثة تتابع السيرفر وهي ظاهرة فقط', (tester) async {
      final repo = _WatchedRepo();
      await _pumpApp(tester, const MessagesScreen(), repo);
      expect(repo.controller.hasListener, isTrue);

      await _openOver(tester, const Scaffold(body: Text('فوقها')));
      expect(repo.controller.hasListener, isFalse);

      await _goBack(tester);
      expect(repo.controller.hasListener, isTrue);

      await tester.pumpWidget(const SizedBox());
      expect(repo.controller.hasListener, isFalse);
    });

    test('لا يُفتح أي اتصال قبل أن تستمع المحادثة، ويُغلق بعدها', () async {
      final client = SupabaseClient('http://127.0.0.1:9', 'test-key');
      addTearDown(client.dispose);
      final repo = SupabaseRepository(client);
      expect(client.getChannels(), isEmpty);
      expect(client.realtime.isConnected, isFalse);

      final subscription = repo.changes.listen((_) {});
      expect(client.getChannels(), hasLength(1));

      await subscription.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(client.getChannels(), isEmpty);
      expect(client.realtime.isConnected, isFalse);
    });
  });

  group('انتقال الصفحة', () {
    testWidgets('الإطار المتأخر لا يجعل الحركة تقفز', (tester) async {
      await _pumpApp(tester, const Scaffold(body: Text('الأولى')), _WatchedRepo());
      Navigator.of(tester.element(find.byType(Scaffold))).push(
        QuickRoute<void>(builder: (_) => const Scaffold(body: Text('الثانية'))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final page = tester.element(find.text('الثانية'));
      final animation = ModalRoute.of(page)!.animation!;
      expect(animation.value, lessThan(.15));

      await tester.pump(const Duration(milliseconds: 300));
      expect(animation.value, lessThan(.25));

      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(animation.value, 1);
    });

    testWidgets('التأخر المستمر لا يطيل الحركة بلا حد', (tester) async {
      await _pumpApp(tester, const Scaffold(body: Text('الأولى')), _WatchedRepo());
      Navigator.of(tester.element(find.byType(Scaffold))).push(
        QuickRoute<void>(builder: (_) => const Scaffold(body: Text('الثانية'))),
      );
      await tester.pump();
      for (var i = 0; i < 2; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 200));
      final page = tester.element(find.text('الثانية'));
      expect(ModalRoute.of(page)!.animation!.value, 1);
    });

    test('زمن الإطار في المشهد: المتأخر يُحسب خطوة عادية', () {
      expect(steadyStep(const Duration(milliseconds: 16)), closeTo(.016, .0001));
      expect(steadyStep(const Duration(milliseconds: 40)), closeTo(.04, .0001));
      expect(steadyStep(const Duration(milliseconds: 200)), closeTo(1 / 60, .0001));
    });
  });
}

class _CountingCategoriesRepo extends _WatchedRepo {
  int workerLists = 0;

  @override
  Future<List<Worker>> listWorkers({int? categoryId, bool onlyAvailable = false}) {
    workerLists++;
    return super.listWorkers(categoryId: categoryId, onlyAvailable: onlyAvailable);
  }
}
