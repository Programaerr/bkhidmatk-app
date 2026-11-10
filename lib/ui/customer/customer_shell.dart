import 'dart:async'; // TMP-DEVICE
import 'dart:ui' show FrameTiming; // TMP-DEVICE

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/scheduler.dart'; // TMP-DEVICE
import 'package:flutter/material.dart';

import '../../core/language.dart';
import '../../data/models.dart';
import '../widgets/shell_layout.dart';
import 'bookings_tab.dart';
import 'guest_gate.dart';
import 'home_tab.dart';
import 'our_work_tab.dart';
import 'profile_tab.dart';
import 'technicians_tab.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key, this.onOpenAdminDashboard});

  /// للمدير فقط: يفتح لوحة التحكم من صفحة حسابه.
  final VoidCallback? onOpenAdminDashboard;

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _index = 0;

  // TMP-DEVICE: cycles the tabs and logs frame times of the portal.
  @override
  void initState() {
    super.initState();
    final timings = <FrameTiming>[];
    var recording = false;
    SchedulerBinding.instance.addTimingsCallback((list) {
      if (recording) timings.addAll(list);
    });
    const tabs = [1, 0, 2, 0, 4, 1, 0, 2, 4, 0];
    var step = 0;
    Timer.periodic(const Duration(milliseconds: 1400), (timer) {
      if (!mounted) return timer.cancel();
      if (step < tabs.length) {
        recording = true;
        _go(tabs[step++]);
        return;
      }
      timer.cancel();
      recording = false;
      double ms(Duration d) => d.inMicroseconds / 1000;
      List<double> sorted(Iterable<double> v) => v.toList()..sort();
      final raster = sorted(timings.map((t) => ms(t.rasterDuration)));
      final build = sorted(timings.map((t) => ms(t.buildDuration)));
      final total = sorted(timings.map((t) => ms(t.totalSpan)));
      String q(List<double> v, double f) => v[(v.length * f).floor().clamp(0, v.length - 1)].toStringAsFixed(1);
      // ignore: avoid_print
      print('TMPPORTAL frames=${timings.length} '
          'build p50=${q(build, .5)} p90=${q(build, .9)} max=${q(build, .999)} '
          'raster p50=${q(raster, .5)} p90=${q(raster, .9)} p99=${q(raster, .99)} max=${q(raster, .999)} '
          'total p90=${q(total, .9)} over11=${total.where((v) => v > 11.1).length} over16=${total.where((v) => v > 16.7).length}');
    });
  }

  // آخر ما جلبته الرئيسية، فيفتح منه تبويب الحرفيين فوراً دون انتظار السيرفر.
  List<Category>? _loadedSections;
  List<Worker>? _loadedWorkers;
  final _technicianChoice = TechniciansChoice();

  @override
  void dispose() {
    _technicianChoice.dispose();
    super.dispose();
  }

  /// يفتح تبويب الحرفيين على نوع الشغل المضغوط عليه، أو على كلهم إن لم يُعطَ اسم.
  void _openSection(String? name) {
    _technicianChoice.choose(name);
    _go(1);
  }

  void _go(int index) {
    // الضيف يتصفح الرئيسية والحرفيين فقط، وبقية التبويبات تطلب منه تسجيل الدخول.
    if (index > 1 && !hasAccount(context)) return;
    // لوحة المفاتيح لا تبقى مفتوحة فوق تبويب آخر.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _index = index);
  }

  // تبقى هي نفسها بين البناءات، فتبديل التبويب لا يعيد بناء التبويبات كلها.
  late final _home = HomeTab(
    onOpenProfile: () => _go(4),
    onOpenSection: _openSection,
    onLoaded: (sections, craftsmen) {
      _loadedSections = sections;
      _loadedWorkers = craftsmen;
    },
  );
  late final _technicians = TechniciansTab(
    loadedSections: () => _loadedSections,
    loadedWorkers: () => _loadedWorkers,
    choice: _technicianChoice,
  );
  late final _bookings = BookingsTab(onBrowse: () => _go(1));
  late final _profile = ProfileTab(
    onOpenBookings: () => _go(2),
    onOpenAdminDashboard: widget.onOpenAdminDashboard,
  );

  // تُبنى مع كل بناء، فتتبع لغة التطبيق. أيقونات بأشكال رموز آبل، وعلى الآيفون الرموز نفسها.
  static List<NavItem> get _items => [
    NavItem(tr('الرئيسية', 'Home'), CupertinoIcons.house, CupertinoIcons.house_fill,
        symbol: 'house.fill'),
    NavItem(tr('الحرفيين', 'Craftsmen'), CupertinoIcons.hammer, CupertinoIcons.hammer_fill,
        symbol: 'hammer.fill'),
    NavItem(tr('حجوزاتي', 'My bookings'), CupertinoIcons.calendar, CupertinoIcons.calendar,
        symbol: 'calendar'),
    NavItem(tr('أعمالنا', 'Our work'), CupertinoIcons.play_rectangle,
        CupertinoIcons.play_rectangle_fill,
        symbol: 'play.rectangle.fill', minimizeOnScroll: false),
    NavItem(tr('حسابي', 'My account'), CupertinoIcons.person_crop_circle,
        CupertinoIcons.person_crop_circle_fill,
        symbol: 'person.crop.circle.fill'),
  ];

  @override
  Widget build(BuildContext context) {
    // زر رجوع الهاتف يرجع من أي تبويب إلى الرئيسية، ومنها يخرج.
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(0);
      },
      child: AppShellLayout(
        index: _index,
        items: _items,
        pages: [
          _home,
          _technicians,
          _bookings,
          OurWorkTab(isActive: _index == 3),
          _profile,
        ],
        onSelect: _go,
      ),
    );
  }
}
