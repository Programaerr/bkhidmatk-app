import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../core/language.dart';
import '../customer/our_work_tab.dart';
import '../customer/profile_tab.dart';
import '../widgets/shell_layout.dart';
import 'worker_requests_tab.dart';

/// غلاف الحرفي: طلبات الحجز باسمه، وقسم «أعمالنا»، وحسابه الشخصي.
/// لا خدمات ولا حجوزات الزبائن الآخرين ولا لوحة التحكم.
class WorkerShell extends StatefulWidget {
  const WorkerShell({super.key});

  @override
  State<WorkerShell> createState() => _WorkerShellState();
}

class _WorkerShellState extends State<WorkerShell> {
  int _index = 0;

  void _go(int index) => setState(() => _index = index);

  late final _requests = const WorkerRequestsTab();
  late final _profile = ProfileTab(
    workerMode: true,
    onOpenBookings: () => _go(0),
  );

  // تُبنى مع كل بناء، فتتبع لغة التطبيق. أيقونات بأشكال رموز آبل، وعلى الآيفون الرموز نفسها.
  static List<NavItem> get _items => [
    NavItem(tr('طلباتي', 'My requests'), CupertinoIcons.tray_full,
        CupertinoIcons.tray_full_fill,
        symbol: 'tray.full.fill'),
    NavItem(tr('أعمالنا', 'Our work'), CupertinoIcons.play_rectangle,
        CupertinoIcons.play_rectangle_fill,
        symbol: 'play.rectangle.fill', minimizeOnScroll: false),
    NavItem(tr('حسابي', 'My account'), CupertinoIcons.person_crop_circle,
        CupertinoIcons.person_crop_circle_fill,
        symbol: 'person.crop.circle.fill'),
  ];

  @override
  Widget build(BuildContext context) {
    // زر رجوع الهاتف يرجع من أي تبويب إلى الطلبات، ومنها يخرج.
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(0);
      },
      child: AppShellLayout(
        index: _index,
        items: _items,
        pages: [
          _requests,
          OurWorkTab(isActive: _index == 1),
          _profile,
        ],
        onSelect: _go,
      ),
    );
  }
}
