import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jaik/core/theme.dart';
import 'package:jaik/data/models.dart';
import 'package:jaik/state/app_state.dart';
import 'package:jaik/ui/auth/push_key.dart';
import 'package:jaik/ui/customer/bookings_tab.dart';
import 'package:jaik/ui/customer/customer_shell.dart';
import 'package:jaik/ui/customer/home_keys.dart';
import 'package:jaik/ui/customer/technicians_tab.dart';
import 'package:jaik/ui/widgets/ui.dart';

import 'fake_repository.dart';

AppUser _customer() => AppUser(
      id: 1,
      name: 'زبون تجريبي',
      phone: '07701234567',
      passwordHash: '',
      role: 'customer',
      createdAt: DateTime(2026),
    );

Booking _booking(int id, String status) => Booking(
      id: id,
      customerId: 1,
      serviceId: 1,
      scheduledAt: DateTime(2026, 11, 3 + id),
      slot: '10:00',
      address: 'بغداد',
      status: status,
      total: 25000,
      createdAt: DateTime(2026, 11, 1),
      serviceTitle: 'صيانة كهرباء',
      workerName: 'أحمد الجبوري',
    );

class _Repo extends FakeRepo {
  _Repo([this.bookings = const []]) : super(customer: _customer());

  final List<Booking> bookings;

  @override
  Future<List<Booking>> bookingsForCustomer(int customerId, {String? status}) async => bookings;
}

final _mixed = [
  _booking(1, BookingStatus.pending),
  _booking(2, BookingStatus.completed),
  _booking(3, BookingStatus.cancelled),
  _booking(4, BookingStatus.completed),
  _booking(5, BookingStatus.inProgress),
];

Future<void> _openBookings(
  WidgetTester tester, {
  _Repo? repo,
  Size size = const Size(391, 870),
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
      value: AppState(repository: repo ?? _Repo())..user = _customer(),
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
  await tester.tap(find.text('حجوزاتي'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Finder _choice(String label) => find.descendant(
      of: find.byType(BookingsTab),
      matching: find.widgetWithText(PushKey, label),
    );

Finder get _browse => find.ancestor(of: find.text('تصفح الحرفيين'), matching: find.byType(PushKey));

Finder get _cards => find.descendant(of: find.byType(BookingsTab), matching: find.byType(StatusPill));

/// وجه الزر من غير جانبه وقاعدته.
Rect _face(WidgetTester tester, Finder key, double faceHeight) {
  final box = tester.getRect(key);
  final inset = PushKey.faceInset * homeKeyChrome;
  return Rect.fromLTWH(box.left + inset, box.top, box.width - inset * 2, faceHeight);
}

void main() {
  group('تبويب الحجوزات', () {
    testWidgets('العنوان كل الحجوزات، والاختيارات الكل والمكتملة والملغاة فقط', (tester) async {
      await _openBookings(tester);
      expect(find.text('كل الحجوزات'), findsOneWidget);
      expect(find.byType(ChoiceKey), findsNWidgets(3));
      expect(_choice('الكل'), findsOneWidget);
      expect(_choice('المكتملة'), findsOneWidget);
      expect(_choice('الملغاة'), findsOneWidget);
      expect(find.text('القادمة'), findsNothing);
      expect(tester.widget<PushKey>(_choice('الكل')).lemon, isTrue);
      expect(tester.widget<PushKey>(_choice('المكتملة')).lemon, isFalse);
    });

    testWidgets('بلا حجوزات يبقى زر تصفح الحرفيين الأصفر وحده في الصفحة', (tester) async {
      await _openBookings(tester);
      expect(_browse, findsOneWidget);
      expect(tester.widget<PushKey>(_browse).lemon, isTrue);
      expect(find.text('لا توجد حجوزات هنا'), findsNothing);
      expect(find.text('تصفح الفنيين'), findsNothing);
      expect(_cards, findsNothing);
    });

    testWidgets('زر تصفح الحرفيين يفتح تبويب الحرفيين', (tester) async {
      await _openBookings(tester);
      await tester.tap(_browse);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byType(TechniciansTab), findsOneWidget);
      expect(find.text('كل الحرفيين'), findsOneWidget);
      expect(TickerMode.valuesOf(tester.element(find.byType(TechniciansTab))).enabled, isTrue);
      expect(
        TickerMode.valuesOf(tester.element(find.byType(BookingsTab, skipOffstage: false))).enabled,
        isFalse,
      );
    });

    testWidgets('الاختيارات تعرض الحجوزات حسب حالتها', (tester) async {
      await _openBookings(tester, repo: _Repo(_mixed));
      expect(_cards, findsNWidgets(5));
      expect(_browse, findsNothing);

      await tester.tap(_choice('المكتملة'));
      await tester.pump();
      expect(tester.widget<PushKey>(_choice('المكتملة')).lemon, isTrue);
      expect(tester.widget<PushKey>(_choice('الكل')).lemon, isFalse);
      expect(_cards, findsNWidgets(2));
      expect(find.text('مكتمل'), findsNWidgets(2));

      await tester.tap(_choice('الملغاة'));
      await tester.pump();
      expect(_cards, findsOneWidget);
      expect(find.text('ملغي'), findsOneWidget);

      await tester.tap(_choice('الكل'));
      await tester.pump();
      expect(_cards, findsNWidgets(5));
    });

    testWidgets('الاختيار الذي ليس فيه حجوزات يعرض زر التصفح', (tester) async {
      await _openBookings(tester, repo: _Repo([_booking(1, BookingStatus.completed)]));
      expect(_browse, findsNothing);
      await tester.tap(_choice('الملغاة'));
      await tester.pump();
      expect(_cards, findsNothing);
      expect(_browse, findsOneWidget);
    });

    testWidgets('الاختيارات في أماكن التصميم، وزر التصفح في وسط المكان الفارغ', (tester) async {
      await _openBookings(tester);
      final faces = [
        for (final label in ['الكل', 'المكتملة', 'الملغاة'])
          _face(tester, _choice(label), ChoiceKey.faceHeight),
      ];
      // في صف واحد يبدأ بالكل من اليمين، والفراغ بينها كما في التصميم.
      for (final face in faces) {
        expect(face.top, closeTo(150.1, .01));
      }
      expect(faces[0].left, greaterThan(faces[1].right));
      expect(faces[1].left, greaterThan(faces[2].right));
      expect(faces[0].left - faces[1].right, closeTo(22.4, .01));
      expect(faces[1].left - faces[2].right, closeTo(22.4, .01));
      // الصف في وسط الشاشة.
      expect((faces[0].right + faces[2].left) / 2, closeTo(391 / 2, .01));
      // لا زر أضيق من التصميم، والاسم الطويل يأخذ عرضه.
      for (final face in faces) {
        expect(face.width, greaterThanOrEqualTo(56.7));
      }

      expect(_face(tester, _browse, 39).width, closeTo(144.7, .01));
      // زر التصفح بجانبه وقاعدته في وسط الشاشة، وبين الاختيارات وشريط التنقل.
      final browse = tester.getRect(_browse);
      expect(browse.center.dx, closeTo(391 / 2, .01));
      final choicesEnd = faces[0].bottom + PushKey.depth * homeKeyChrome;
      final barTop = 870 - MediaQuery.paddingOf(tester.element(find.byType(BookingsTab))).bottom;
      expect(browse.top - choicesEnd, closeTo(barTop - browse.bottom, .01));
    });

    testWidgets('آخر حجز يبقى فوق شريط التنقل الزجاجي', (tester) async {
      await _openBookings(
        tester,
        repo: _Repo([for (var i = 1; i <= 12; i++) _booking(i, BookingStatus.completed)]),
        size: const Size(392, 700),
      );
      final bar = tester.getRect(find.byKey(const ValueKey('glass-navigation-bar')));
      final list = find.descendant(of: find.byType(BookingsTab), matching: find.byType(Scrollable)).first;
      await tester.drag(list, const Offset(0, -3000));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      final last = find.descendant(of: find.byType(BookingsTab), matching: find.byType(SoftCard)).last;
      expect(tester.getRect(last).bottom, lessThanOrEqualTo(bar.top));
    });

    testWidgets('يعمل في الوضع الليلي', (tester) async {
      await _openBookings(tester, theme: AppTheme.dark());
      expect(tester.takeException(), isNull);
      expect(find.text('كل الحجوزات'), findsOneWidget);
      expect(_browse, findsOneWidget);
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
        await _openBookings(tester, size: size, textScale: scale);
        expect(tester.takeException(), isNull);

        await _openBookings(tester, repo: _Repo(_mixed), size: size, textScale: scale);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
