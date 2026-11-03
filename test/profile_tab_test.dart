import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jaik/core/theme.dart';
import 'package:jaik/data/models.dart';
import 'package:jaik/state/app_state.dart';
import 'package:jaik/ui/auth/day_night_switch.dart';
import 'package:jaik/ui/auth/push_key.dart';
import 'package:jaik/ui/customer/bookings_tab.dart';
import 'package:jaik/ui/customer/customer_shell.dart';
import 'package:jaik/ui/customer/home_keys.dart';
import 'package:jaik/ui/customer/messages_screen.dart';
import 'package:jaik/ui/customer/profile_tab.dart';
import 'package:jaik/ui/worker/worker_shell.dart';

import 'fake_repository.dart';
import 'route_frames.dart';

AppUser _user({String role = 'customer'}) => AppUser(
      id: 1,
      name: 'محمد باقر',
      phone: '07701234567',
      passwordHash: '',
      role: role,
      city: 'بغداد',
      createdAt: DateTime(2026),
    );

Future<AppState> _openProfile(
  WidgetTester tester, {
  Widget shell = const CustomerShell(),
  String role = 'customer',
  Size size = const Size(391, 870),
  FakeViewPadding padding = FakeViewPadding.zero,
  double textScale = 1,
  bool night = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..padding = padding
    ..viewPadding = padding;
  addTearDown(tester.view.reset);
  final user = _user(role: role);
  final state = AppState(repository: FakeRepo(customer: user))
    ..user = user
    ..themeMode = night ? ThemeMode.dark : ThemeMode.light;
  // تطبيق جديد في كل مرة، مثل فتح التطبيق من أوله.
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: Consumer<AppState>(
        builder: (context, state, _) => MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: state.themeMode,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: Directionality(textDirection: TextDirection.rtl, child: child!),
          ),
          home: _Gate(shell),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 60));
  await tester.tap(find.text('حسابي'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return state;
}

/// مثل باب التطبيق: بعد الخروج لا يبقى غلاف الزبون.
class _Gate extends StatelessWidget {
  const _Gate(this.shell);

  final Widget shell;

  @override
  Widget build(BuildContext context) =>
      context.watch<AppState>().user == null ? const Scaffold(body: Text('خرج')) : shell;
}

Finder _inProfile(Finder finder) => find.descendant(of: find.byType(ProfileTab), matching: finder);

Finder _key(String text) =>
    find.ancestor(of: _inProfile(find.text(text)), matching: find.byType(PushKey)).first;

Finder get _logoutKey => _inProfile(find.byWidgetPredicate((w) => w is PushKey && w.red));

Finder get _card => _inProfile(find.byWidgetPredicate((w) => w is PushKey && w.lemon));

/// وجه الزر من غير جانبه وقاعدته.
Rect _face(WidgetTester tester, Finder key, {double unit = 1}) {
  final box = tester.getRect(key);
  final chrome = unit * homeKeyChrome;
  return Rect.fromLTRB(
    box.left + PushKey.faceInset * chrome,
    box.top,
    box.right - PushKey.faceInset * chrome,
    box.bottom - PushKey.depth * chrome,
  );
}

void main() {
  group('تبويب الملف الشخصي', () {
    testWidgets('العنوان الملف الشخصي، والبطاقة الصفراء فيها الاسم والرقم والمحافظة بلا عدادات', (tester) async {
      await _openProfile(tester);
      expect(find.text('الملف الشخصي'), findsOneWidget);
      expect(_card, findsOneWidget);
      final card = _face(tester, _card);
      for (final text in ['محمد باقر', '07701234567', 'بغداد']) {
        expect(_inProfile(find.text(text)), findsOneWidget, reason: text);
        final box = tester.getRect(_inProfile(find.text(text)));
        expect(card.contains(box.topLeft) && card.contains(box.bottomRight), isTrue, reason: text);
      }
      for (final gone in ['حجز', 'وصل', 'وصولات الدفع', 'عن جايك']) {
        expect(_inProfile(find.text(gone)), findsNothing, reason: gone);
      }
    });

    testWidgets('زر التعديل في البطاقة يفتح تعديل الملف الشخصي', (tester) async {
      await _openProfile(tester);
      await tester.tap(
        find.byWidgetPredicate((w) => w is PushKeyCircle && w.label == 'تعديل الملف الشخصي'),
      );
      await tester.pump();
      await pumpRouteFrames(tester);
      expect(find.text('حفظ التغييرات'), findsOneWidget);
    });

    testWidgets('حجوزاتي يفتح تبويب الحجوزات', (tester) async {
      await _openProfile(tester);
      await tester.tap(_key('حجوزاتي'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(TickerMode.valuesOf(tester.element(find.byType(BookingsTab))).enabled, isTrue);
    });

    testWidgets('الرسائل والدعم يفتح صفحة الرسائل', (tester) async {
      await _openProfile(tester);
      await tester.tap(_key('الرسائل والدعم'));
      await tester.pump();
      await pumpRouteFrames(tester);
      expect(find.byType(MessagesScreen), findsOneWidget);
    });

    testWidgets('زر الوضع الليلي يبدل بين الليل والنهار', (tester) async {
      final state = await _openProfile(tester);
      expect(tester.widget<DayNightSwitch>(find.byType(DayNightSwitch)).night, isFalse);
      await tester.tap(_key('الوضع الليلي'));
      await tester.pump();
      expect(state.themeMode, ThemeMode.dark);
      await tester.tap(_key('الوضع الليلي'));
      await tester.pump();
      expect(state.themeMode, ThemeMode.light);
    });

    testWidgets('زر اللغة يبدل بين العربي والإنجليزي', (tester) async {
      final state = await _openProfile(tester);
      expect(state.english, isFalse);
      await tester.tap(_key('اللغة'));
      await tester.pump();
      expect(state.english, isTrue);
      await tester.tap(_key('اللغة'));
      await tester.pump();
      expect(state.english, isFalse);
    });

    testWidgets('زر تسجيل الخروج أحمر ويسأل قبل الخروج', (tester) async {
      final state = await _openProfile(tester);
      expect(_logoutKey, findsOneWidget);
      expect(find.descendant(of: _logoutKey, matching: find.text('تسجيل الخروج')), findsOneWidget);
      await tester.tap(_logoutKey);
      await tester.pump();
      await pumpRouteFrames(tester);
      expect(find.text('هل تريد تسجيل الخروج من حسابك؟'), findsOneWidget);
      await tester.tap(find.text('خروج'));
      await tester.pump();
      await pumpRouteFrames(tester);
      expect(state.user, isNull);
    });

    testWidgets('لوحة التحكم للمدير فقط، والموظف لا يرى حجوزاتي', (tester) async {
      await _openProfile(tester);
      expect(_inProfile(find.text('لوحة التحكم')), findsNothing);

      await _openProfile(tester, shell: CustomerShell(onOpenAdminDashboard: () {}), role: 'admin');
      expect(_inProfile(find.text('لوحة التحكم')), findsOneWidget);

      await _openProfile(tester, shell: const WorkerShell(), role: 'worker');
      expect(_inProfile(find.text('حجوزاتي')), findsNothing);
      expect(_inProfile(find.text('الرسائل والدعم')), findsOneWidget);
    });

    testWidgets('على الشاشة الطويلة كل زر في مكانه من التصميم ووسط الشاشة', (tester) async {
      await _openProfile(tester, size: const Size(391, 1000));
      final tops = {
        'حجوزاتي': 345.7,
        'الرسائل والدعم': 435.6,
        'الوضع الليلي': 539.3,
        'اللغة': 617.1,
      };
      expect(_face(tester, _card).top, closeTo(168.6, .1));
      for (final MapEntry(key: text, value: top) in tops.entries) {
        expect(_face(tester, _key(text)).top, closeTo(top, .1), reason: text);
      }
      expect(_face(tester, _logoutKey).top, closeTo(728.3, .1));
      for (final key in [_card, _key('حجوزاتي'), _key('اللغة'), _logoutKey]) {
        final face = _face(tester, key);
        expect(face.width, closeTo(279.9, .01));
        expect(face.center.dx, closeTo(391 / 2, .01));
      }
    });

    testWidgets('في هاتف المستخدم يظهر زر الخروج كله فوق شريط التنقل', (tester) async {
      await _openProfile(
        tester,
        size: const Size(392.7, 872.7),
        padding: const FakeViewPadding(top: 38.4, bottom: 48),
      );
      final bar = tester.getRect(find.byKey(const ValueKey('glass-navigation-bar')));
      final logout = tester.getRect(_logoutKey);
      expect(logout.bottom, lessThan(bar.top));
      // تضيق الفراغات لا الأزرار.
      expect(_face(tester, _logoutKey, unit: 392.7 / 391).height, closeTo(39.0 * 392.7 / 391, .01));
      expect(_face(tester, _card).top, greaterThan(tester.getRect(find.text('الملف الشخصي')).bottom));
    });

    testWidgets('يعمل في الوضع الليلي', (tester) async {
      await _openProfile(tester, night: true);
      expect(tester.takeException(), isNull);
      expect(tester.widget<DayNightSwitch>(find.byType(DayNightSwitch)).night, isTrue);
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
        await _openProfile(tester, size: size, textScale: scale);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
