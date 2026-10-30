import 'package:flutter/material.dart';

import '../customer/our_work_tab.dart';
import '../customer/profile_tab.dart';
import '../widgets/shell_layout.dart';

/// غلاف الموظف بالتوضيف: يرى فقط ما تسمح به الإدارة —
/// قسم «أعمالنا» وحسابه الشخصي، دون حجوزات أو خدمات أو منشورات.
class WorkerShell extends StatefulWidget {
  const WorkerShell({super.key});

  @override
  State<WorkerShell> createState() => _WorkerShellState();
}

class _WorkerShellState extends State<WorkerShell> {
  int _index = 0;
  int _tick = 0;

  static const _items = [
    NavItem('أعمالنا', Icons.video_library_outlined, Icons.video_library_rounded),
    NavItem('حسابي', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  void _go(int index) {
    setState(() {
      _index = index;
      _tick++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      OurWorkTab(refreshTick: _tick),
      ProfileTab(
        workerMode: true,
        onOpenBookings: () => _go(0),
      ),
    ];

    return AppShellLayout(
      index: _index,
      items: _items,
      pages: pages,
      onSelect: _go,
    );
  }
}
