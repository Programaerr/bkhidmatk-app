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

  // تُبنى مع كل بناء، فتتبع لغة التطبيق.
  static List<NavItem> get _items => [
    NavItem(tr('طلباتي', 'My requests'), Icons.assignment_outlined, Icons.assignment_rounded),
    NavItem(tr('أعمالنا', 'Our work'), Icons.video_library_outlined, Icons.video_library_rounded, darkBar: true),
    NavItem(tr('حسابي', 'My account'), Icons.person_outline_rounded, Icons.person_rounded),
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
